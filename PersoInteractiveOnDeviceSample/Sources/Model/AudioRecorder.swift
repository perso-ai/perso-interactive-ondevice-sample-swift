//
//  Copyright © 2025 ESTsoft. All rights reserved.

import Accelerate
import AVFoundation
import Combine
import Foundation

final class AudioRecorder {

    private var cancellables = Set<AnyCancellable>()

    private var audioEngine: AVAudioEngine?
    private let targetSampleRate: Double = 16000
    private var targetFormat: AVAudioFormat?

    private var recordedBuffers: [AVAudioPCMBuffer] = []

    /// Recording Status
    /// - If you want to continuously observe state changes, you can use a `Publisher`.
    @Published public private(set) var isRecording: Bool = false

    init() {
        setUpObservers()
    }

    deinit {
        Task { [weak self] in
            try? await self?.stopRecording()
        }
    }

    /// Starts recording audio from the microphone.
    ///
    /// This method sets up an audio tap on the input node of the audio engine, converts the audio buffer to the desired format,
    /// and stores it for further processing. The recording process starts the audio engine and begins capturing audio data.
    ///
    /// - Throws:
    ///   - `AudioRecorderError.microphonePermissionDenied`: If microphone permission is not granted.
    ///   - `AudioRecorderError.alreadyRecording`: If the recording is already in progress.
    ///   - `AudioRecorderError.recordingFailed`: If there is a failure in starting the audio engine.
    ///
    /// - Note: Ensure that `isRecording` is checked before calling this method to avoid attempting to start multiple recordings simultaneously.
    func startRecording() async throws {
        guard await checkMicrophonePermission() else {
            throw AudioRecorderError.microphonePermissionDenied
        }

        #if os(macOS)
        guard !AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone, .external],
                                                mediaType: .audio,
                                                position: .unspecified).devices.isEmpty else {
            throw AudioRecorderError.requiredInputDevices
        }
        #endif

        guard !isRecording else { throw AudioRecorderError.alreadyRecording }

        recordedBuffers.removeAll()
        audioEngine = try setupAudioEngine()
        isRecording = true
    }

    /// Stops the ongoing audio recording and returns the recorded audio data in `Data` format.
    ///
    /// This method stops the audio engine, removes the audio tap from the input node, and processes the captured audio buffers.
    /// The audio data is then converted into the specified format and returned as a `Data` object.
    ///
    /// - Returns: A `Data` object containing the recorded audio in the specified format.
    ///
    /// - Throws: Errors that occur during the process of writing the audio data to a file and reading it back.
    ///
    /// - Note: The method uses an asynchronous continuation to handle the asynchronous nature of stopping the recording and processing the audio data.
    /// Ensure that `isRecording` is true before calling this method, as it will throw an error if no recording is active.
    func stopRecording() async throws -> Data {
        defer {
            self.recordedBuffers.removeAll()
            self.isRecording = false
        }

        let audioData = try await Task { [weak self] in
            guard let self = self else {
                throw AudioRecorderError.recordingFailed
            }

            guard self.isRecording else {
                throw AudioRecorderError.notRecordingMode
            }

            self.audioEngine?.inputNode.removeTap(onBus: 0)
            self.audioEngine?.stop()
            self.audioEngine = nil

            guard !self.recordedBuffers.isEmpty,
                  let targetFormat = self.targetFormat,
                  let buffer = AVAudioPCMBuffer(buffers: self.recordedBuffers, format: targetFormat)
            else {
                throw AudioRecorderError.notExistRecordingData
            }

            let url = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)
                .first!
                .appending(path: "temp.wav")

            try self.writeToAudioFile(buffer, url: url)
            return try Data(contentsOf: url)
        }.value

        return audioData
    }

}

extension AudioRecorder {

    private func checkMicrophonePermission() async -> Bool {
        return await AVAudioApplication.requestRecordPermission()
    }

    private func setupAudioEngine() throws -> AVAudioEngine {
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let bus: AVAudioNodeBus = 0

        let originAudioFormat = inputNode.outputFormat(forBus: bus)

        // Target format (16kHz, 1 channel)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: AVAudioChannelCount(1),
            interleaved: false
        ) else { throw AudioRecorderError.recordingFailed }

        self.targetFormat = targetFormat

        guard let converter = AVAudioConverter(from: originAudioFormat, to: targetFormat) else {
            throw AudioRecorderError.formatConversionIsNotPossible
        }

        let latency: TimeInterval = 0.1  // 100ms - 400ms supported
        let bufferSize = AVAudioFrameCount(originAudioFormat.sampleRate * latency)

        inputNode.installTap(onBus: bus, bufferSize: bufferSize, format: originAudioFormat) { [weak self] buffer, _ in
            guard let self else { return }

            do {
                // Resample audio buffer from 48kHz to 16kHz
                let resampledBuffer = try resampleBuffer(buffer, with: converter)
                recordedBuffers.append(resampledBuffer)
            } catch {
                self.recordedBuffers.removeAll()
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        return audioEngine
    }

    /// Sets up observers for audio route changes.
    ///
    /// This method configures a Combine publisher to listen for `AVAudioSession.routeChangeNotification` notifications.
    private func setUpObservers() {
        #if os(iOS) || os(visionOS)
        NotificationCenter.default
            .publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                cancelRecording()
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                cancelRecording()
            }
            .store(in: &cancellables)
        #endif
    }

    private func cancelRecording() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        recordedBuffers.removeAll()
        isRecording = false
    }

    private func writeToAudioFile(_ buffer: AVAudioPCMBuffer, url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        let audioFile = try AVAudioFile(forWriting: url, settings: buffer.format.settings)
        try audioFile.write(from: buffer)
    }

    private func resampleBuffer(
        _ buffer: AVAudioPCMBuffer,
        with converter: AVAudioConverter
    ) throws -> AVAudioPCMBuffer {
        var capacity = converter.outputFormat.sampleRate * Double(buffer.frameLength) / converter.inputFormat.sampleRate

        // Check if the capacity is a whole number
        if capacity.truncatingRemainder(dividingBy: 1) != 0 {
            // Round to the nearest whole number
            let roundedCapacity = capacity.rounded(.toNearestOrEven)
            capacity = roundedCapacity
        }

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: converter.outputFormat,
            frameCapacity: AVAudioFrameCount(capacity)
        ) else {
            throw AudioRecorderError.unsupportedFormat
        }

        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if buffer.frameLength == 0 {
                outStatus.pointee = .endOfStream
                return nil
            } else {
                outStatus.pointee = .haveData
                return buffer
            }
        }

        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

        if status == .error {
            throw AudioRecorderError.conversionFailed
        }

        return convertedBuffer
    }
}

// MARK: - AudioRecorderError

enum AudioRecorderError: LocalizedError {

    /// `AudioRecorder` is already recording
    case alreadyRecording

    /// `AVAudioEngine` is not available
    case recordingFailed

    /// `AVAudioEngine` is not running.
    case notRecordingMode

    /// recording data is empty.
    case notExistRecordingData

    /// Format conversion is not possible
    case formatConversionIsNotPossible

    /// An exception is raised if the format is not PCM
    case unsupportedFormat

    /// Conversion fails
    case conversionFailed

    case requiredInputDevices

    case microphonePermissionDenied

    var errorDescription: String? {
        switch self {
        case .requiredInputDevices:
            return "Please connect an input device."
        case .microphonePermissionDenied:
            return "Microphone permission is required to record audio. \nPlease enable microphone access in 『Settings → Privacy & Security → Microphone』 and allow access for this app."
        case .notExistRecordingData:
            return "No speech was detected in the audio. Please speak clearly and try again. \nIf this issue persists, please check your microphone connection."
        default:
            return ""
        }
    }
}

// MARK: - AVAudioPCMBuffer+Extension

extension AVAudioPCMBuffer {

    convenience init?(buffers: [AVAudioPCMBuffer], format: AVAudioFormat) {
        let totalFrameCount = buffers.reduce(0) { $0 + $1.frameLength }
        self.init(pcmFormat: format, frameCapacity: totalFrameCount)

        buffers.forEach {
            self.append($0)
        }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        append(buffer, startingFrame: 0, frameCount: buffer.frameLength)
    }

    /// Add to an existing buffer with specific starting frame and size
    /// - Parameters:
    ///   - buffer: Buffer to append
    ///   - startingFrame: Starting frame location
    ///   - frameCount: Number of frames to append
    func append(
        _ buffer: AVAudioPCMBuffer,
        startingFrame: AVAudioFramePosition,
        frameCount: AVAudioFrameCount
    ) {
        precondition(format == buffer.format, "Format mismatch")
        precondition(
            startingFrame + AVAudioFramePosition(frameCount) <= AVAudioFramePosition(buffer.frameLength),
            "Insufficient audio in buffer"
        )
        precondition(frameLength + frameCount <= frameCapacity, "Insufficient space in buffer")

        let dst1 = floatChannelData![0]
        let src1 = buffer.floatChannelData![0]

        memcpy(
            dst1.advanced(by: stride * Int(frameLength)),
            src1.advanced(by: stride * Int(startingFrame)),
            Int(frameCount) * stride * MemoryLayout<Float>.size
        )

        frameLength += frameCount
    }
}
