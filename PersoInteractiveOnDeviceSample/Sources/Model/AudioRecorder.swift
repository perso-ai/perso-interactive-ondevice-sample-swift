//
//  Copyright © 2025 ESTsoft. All rights reserved.

import Accelerate
import AVFoundation
import Combine
import Foundation
import os

// SAFETY: @unchecked Sendable is justified because all shared mutable state
// is protected by `mutableState: OSAllocatedUnfairLock<MutableState>`.
// isRecording is only mutated from main-thread contexts.
//
// When adopting Swift 6.1+, `Mutex.withLockUnchecked` can be used
// instead of `OSAllocatedUnfairLock` to handle non-Sendable types in the same way.
final class AudioRecorder: @unchecked Sendable {

    private var cancellables = Set<AnyCancellable>()

    private let targetSampleRate: Double = 16000

    private struct MutableState {
        var audioEngine: AVAudioEngine?
        var recordedBuffers: [AVAudioPCMBuffer] = []
        var targetFormat: AVAudioFormat?
        var converter: AVAudioConverter?
        var originAudioFormat: AVAudioFormat?
    }
    private let mutableState = OSAllocatedUnfairLock(uncheckedState: MutableState())

    /// Recording Status
    /// - If you want to continuously observe state changes, you can use a `Publisher`.
    @Published public private(set) var isRecording: Bool = false

    init() {
        setUpObservers()
    }

    deinit {
        mutableState.withLockUnchecked { state in
            state.audioEngine?.inputNode.removeTap(onBus: 0)
            state.audioEngine?.stop()
            state.audioEngine = nil
            state.recordedBuffers.removeAll()
        }
    }

    // MARK: - Engine Lifecycle

    /// Prepares and starts the audio engine to secure the HALC proxy I/O context
    /// before other audio consumers (e.g., SDK TTS) occupy the audio hardware.
    ///
    /// Call this **before** initializing the SDK session.
    func prepare() throws {
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let bus: AVAudioNodeBus = 0

        let originAudioFormat = inputNode.outputFormat(forBus: bus)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: AVAudioChannelCount(1),
            interleaved: false
        ) else { throw AudioRecorderError.recordingFailed }

        guard let converter = AVAudioConverter(from: originAudioFormat, to: targetFormat) else {
            throw AudioRecorderError.formatConversionIsNotPossible
        }

        audioEngine.prepare()
        try audioEngine.start()

        mutableState.withLockUnchecked { state in
            state.audioEngine = audioEngine
            state.targetFormat = targetFormat
            state.converter = converter
            state.originAudioFormat = originAudioFormat
        }
    }

    // MARK: - Recording

    /// Starts recording audio from the microphone.
    ///
    /// If the engine was pre-started via `prepare()`, installs a tap on the existing engine.
    /// Otherwise, creates and starts a new engine (fallback).
    ///
    /// - Throws:
    ///   - `AudioRecorderError.microphonePermissionDenied`: If microphone permission is not granted.
    ///   - `AudioRecorderError.alreadyRecording`: If the recording is already in progress.
    ///   - `AudioRecorderError.recordingFailed`: If there is a failure in starting the audio engine.
    ///
    /// - Note: Ensure that `isRecording` is checked before calling this method to avoid attempting to start multiple recordings simultaneously.
    @MainActor
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

        let (engine, converter, originFormat) = mutableState.withLockUnchecked { state in
            state.recordedBuffers.removeAll()
            return (state.audioEngine, state.converter, state.originAudioFormat)
        }

        if let engine, let converter, let originFormat {
            // Engine already prepared — restart if needed, then install tap
            if !engine.isRunning {
                engine.prepare()
                try engine.start()
            }
            try installTap(on: engine, converter: converter, format: originFormat)
        } else {
            // Fallback: create and start a new engine
            let newEngine = try setupAudioEngine()
            mutableState.withLockUnchecked { $0.audioEngine = newEngine }
        }

        isRecording = true
    }

    /// Stops the ongoing audio recording and returns the recorded audio data in `Data` format.
    ///
    /// Removes the tap but keeps the engine running for future recordings.
    ///
    /// - Returns: A `Data` object containing the recorded audio in the specified format.
    ///
    /// - Throws: Errors that occur during the process of writing the audio data to a file and reading it back.
    @MainActor
    func stopRecording() async throws -> Data {
        defer {
            mutableState.withLockUnchecked { $0.recordedBuffers.removeAll() }
            self.isRecording = false
        }

        guard isRecording else {
            throw AudioRecorderError.notRecordingMode
        }

        // Remove tap only — keep engine running
        let (buffers, targetFormat) = mutableState.withLockUnchecked { state -> ([AVAudioPCMBuffer], AVAudioFormat?) in
            state.audioEngine?.inputNode.removeTap(onBus: 0)
            return (state.recordedBuffers, state.targetFormat)
        }

        guard !buffers.isEmpty,
              let targetFormat,
              let buffer = AVAudioPCMBuffer(buffers: buffers, format: targetFormat)
        else {
            throw AudioRecorderError.notExistRecordingData
        }

        let url = FileManager.default.temporaryDirectory
            .appending(path: "temp_recording.wav")

        try writeToAudioFile(buffer, url: url)
        let data = try Data(contentsOf: url)
        try? FileManager.default.removeItem(at: url)
        return data
    }

}

extension AudioRecorder {

    private func checkMicrophonePermission() async -> Bool {
        return await AVAudioApplication.requestRecordPermission()
    }

    /// Installs a recording tap on the engine's input node.
    private func installTap(
        on engine: AVAudioEngine,
        converter: AVAudioConverter,
        format: AVAudioFormat
    ) throws {
        let bus: AVAudioNodeBus = 0
        let latency: TimeInterval = 0.1
        let bufferSize = AVAudioFrameCount(format.sampleRate * latency)

        engine.inputNode.installTap(onBus: bus, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            guard buffer.frameLength > 0 else { return }

            do {
                let resampledBuffer = try resampleBuffer(buffer, with: converter)
                mutableState.withLockUnchecked { $0.recordedBuffers.append(resampledBuffer) }
            } catch {
                // Skip failed buffer instead of clearing all previously captured audio
            }
        }
    }

    /// Fallback: creates and starts a new audio engine with tap installed.
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

        mutableState.withLockUnchecked { state in
            state.targetFormat = targetFormat
            state.originAudioFormat = originAudioFormat
        }

        guard let converter = AVAudioConverter(from: originAudioFormat, to: targetFormat) else {
            throw AudioRecorderError.formatConversionIsNotPossible
        }

        mutableState.withLockUnchecked { $0.converter = converter }

        try installTap(on: audioEngine, converter: converter, format: originAudioFormat)

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
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                cancelRecording()
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                cancelRecording()
            }
            .store(in: &cancellables)
        #endif
    }

    private func cancelRecording() {
        mutableState.withLockUnchecked { state in
            state.audioEngine?.inputNode.removeTap(onBus: 0)
            // Keep engine running — only remove tap
        }
        // Use Task { @MainActor } instead of MainActor.assumeIsolated.
        // receive(on: RunLoop.main) does not guarantee @MainActor isolation —
        // it delivers on the main run loop but that is not the same execution
        // context that the Swift runtime considers @MainActor-isolated.
        // assumeIsolated is a runtime precondition, not a hop: calling it on
        // a thread that is merely "main-runloop" but not @MainActor causes
        // unsynchronized access to the @Published isRecording property, which
        // corrupts Combine's internal reference graph and crashes in
        // swift_getObjectType when the runtime tries to read the isa pointer
        // of a partially-freed object.
        Task { @MainActor [weak self] in
            self?.isRecording = false
        }
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

        // SAFETY: nonisolated(unsafe) is required because AVAudioPCMBuffer is not Sendable.
        // The buffer is only read (never mutated) in the inputBlock closure, and its
        // lifetime is scoped to this function call.
        nonisolated(unsafe) let buffer = buffer
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
