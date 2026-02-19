//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import AVFAudio
import Combine
import Foundation

import PersoInteractiveOnDeviceSDK

@MainActor
final class MainViewModel: ObservableObject {

    // MARK: - State Definitions

    /// Represents the chat response state for UI feedback
    enum ChatResponseState: Equatable {
        case idle           // No active processing
        case waiting        // Sent message, waiting for first LLM chunk
        case streaming      // Receiving response chunks
        case error(String)  // Error occurred
    }

    /// Represents the overall UI state of the application
    enum UIState {
        case idle                           // Waiting to start
        case started(PersoInteractiveSession)       // Active session with SDK
        case terminated                     // Session ended
        case error(String)                  // Error occurred

        var isStarted: Bool {
            if case .started = self { return true }
            return false
        }
    }

    /// Represents the AI human avatar state
    enum AIHumanState {
        case idle           // Not active
        case transition     // Transitioning between states
        case standby        // Ready to speak
        case speaking       // Currently speaking
    }

    /// Represents the backend processing state
    enum ProcessingState {
        case idle       // No processing
        case stt        // Speech-to-Text in progress
        case llm        // LLM completion in progress
    }

    // MARK: - Properties

    /// The active session (SDK core object)
    private var session: PersoInteractiveSession?

    /// The session configuration
    private let configuration: SessionConfiguration

    /// Current backend processing state
    @Published var processingState: ProcessingState = .idle

    /// Current chat response state for UI feedback
    @Published var chatResponseState: ChatResponseState = .idle

    /// Last sent message for retry capability
    @Published private(set) var lastSentMessage: String?

    /// Whether chat history is visible (iOS only)
    @Published var isChatHistoryVisible: Bool = true

    /// Accumulated streaming response text (shown during streaming)
    @Published var streamingResponse: String = ""

    /// Chat message history
    @Published var messages: [ChatMessage] = []

    /// Current AI human state
    @Published private(set) var aiHumanState: AIHumanState = .idle

    /// Current UI state
    @Published private(set) var uiState: UIState = .idle

    /// Recording status
    @Published private(set) var isRecording: Bool = false

    private var cancellables = Set<AnyCancellable>()

    /// Audio recorder for voice input
    private let recorder = AudioRecorder()

    /// Task for SDK initialization
    private var initTask: Task<Void, Never>?

    /// Task for managing async conversation processing
    private var processingTask: Task<Void, Never>?

    /// Callback for handling assistant message chunks (for TTS)
    private(set) var handleAssistantMessage: (String) -> Void = { _ in }

    /// Callback to stop speech
    var stopSpeech: (() async -> Void)?

    /// Callback to start recording
    var startRecording: (() -> Void)?

    // MARK: - Initialization

    deinit {
        initTask?.cancel()
        processingTask?.cancel()
    }

    init(configuration: SessionConfiguration) {
        self.configuration = configuration

        initTask = Task { [weak self] in
            do {
                // STEP 1: Load the SDK (prepares models and resources)
                try await PersoInteractive.load()

                // STEP 2: Warmup the SDK (optimizes for first use)
                try await PersoInteractive.warmup()

                // STEP 3: Initialize a new session
                guard let self else { return }
                await self.initializeSession()

                // STEP 4: Bind UI state to properties
                self.bind()
            } catch {
                guard let self else { return }
                self.uiState = .error("initialization occured an error: \(error).\nPlease try again.")
            }
        }
    }

    // MARK: - Public Methods

    /// Initializes or reinitializes the chat session
    /// This demonstrates the complete SDK session setup flow
    func initializeSession() async {
        // Stop existing session before creating a new one
        if session != nil {
            isRestarting = true
            PersoInteractive.stopSession()
            session = nil
        }

        uiState = .idle
        aiHumanState = .idle
        processingState = .idle
        chatResponseState = .idle
        isChatHistoryVisible = false

        clearHistory()

        do {
            // Create a new session with the provided configuration
            try await createSession()
        } catch {
            uiState = .error("Unable to create session: \(error.localizedDescription)")
        }
    }

    /// Sends a text message to the LLM
    /// - Parameter message: The user's text message
    func sendMessage(_ message: String) {
        // Cancel any ongoing task before sending
        if aiHumanState == .speaking || processingState != .idle {
            processingTask?.cancel()
            processingTask = nil
            Task { await stopSpeech?() }
            processingState = .idle
            chatResponseState = .idle
        }

        let userMessage: ChatMessage = .user(message)
        messages.append(userMessage)
        lastSentMessage = message

        processingTask?.cancel()
        processingTask = Task { [weak self] in
            await self?.processConversation(message: message)
        }
    }

    /// Retries the last sent message after an error
    func retryLastMessage() {
        guard let message = lastSentMessage else { return }
        chatResponseState = .idle
        processingTask = Task { [weak self] in
            await self?.processConversation(message: message)
        }
    }

    /// Sets the callback for handling assistant message chunks
    /// - Parameter callback: Function to handle each message chunk
    func handleAssistantMessage(_ callback: @escaping (String) -> Void) {
        handleAssistantMessage = callback
    }

}

// MARK: - User Actions

extension MainViewModel {
    /// Handles the stop speech button tap
    func stopSpeechButtonDidTap() {
        resetConversationState()
    }

    /// Clears the conversation history
    func clearHistory() {
        session?.messages.removeAll()
        messages.removeAll()
    }

    /// Restarts the session completely (stops speech, clears state, reinitializes)
    func restartSession() {
        processingTask?.cancel()
        processingTask = nil
        Task {
            await stopSpeech?()
            stopSpeech = nil
            startRecording = nil
            processingState = .idle
            chatResponseState = .idle
            streamingResponse = ""
            await initializeSession()
        }
    }

    /// Handles the record button tap (starts voice recording)
    func recordButtonDidTap() {
        _startRecording()
    }

    /// Handles the record stop button tap (stops recording and processes audio)
    func recordStopButtonDidTap() {
        stopRecording()
    }

    /// Updates the AI human avatar state
    func updateHumanState(_ state: AIHumanState) {
        let previous = self.aiHumanState
        self.aiHumanState = state

        // Reset processingState when speaking finishes and returns to standby/idle
        if previous == .speaking && (state == .standby || state == .idle) {
            if processingTask == nil {
                processingState = .idle
                chatResponseState = .idle
            }
        }
    }
}

// MARK: - Private Methods

extension MainViewModel {
    /// Binds recorder state to view model properties
    private func bind() {
        recorder.$isRecording
            .receive(on: RunLoop.main)
            .sink { [weak self] isRecording in
                MainActor.assumeIsolated {
                    self?.isRecording = isRecording
                }
            }
            .store(in: &cancellables)

    }

    /// Creates a new session with the provided configuration
    /// This demonstrates how to configure a session with STT, LLM, and TTS capabilities
    private func createSession() async throws {
        let sttType = configuration.sttType
        let llmType = configuration.llmType
        let prompt = configuration.prompt
        let document = configuration.document
        let ttsType = configuration.ttsType
        let mcpServers = configuration.mcpServers

        // IMPORTANT: Create session with selected capabilities
        // The order matters: STT -> LLM -> TTS represents the processing pipeline
        // SAFETY: nonisolated(unsafe) is required because the SDK expects a non-Sendable
        // closure. This closure only accesses self via [weak self] and dispatches all
        // state mutations to @MainActor via Task { @MainActor in }.
        nonisolated(unsafe) let statusHandler: (PersoInteractiveSession.SessionStatus) -> Void = { [weak self] sessionStatus in
            guard let self else { return }

            // Monitor session lifecycle
            switch sessionStatus {
            case .started:
                break
            case .terminated:
                Task { @MainActor in
                    self.session = nil
                    self.uiState = .terminated
                }
            default:
                break
            }
        }

        let session = try await PersoInteractive.createSession(
            for: [
                // Speech recognition
                .speechToText(type: sttType),
                // Language model with system prompt and optional document context
                .largeLanguageModel(llmType: llmType,
                                    promptID: prompt.id,
                                    documentID: document?.id,
                                    mcpServerIDs: mcpServers.map(\.id)),
                // Speech synthesis
                .textToSpeech(type: ttsType)
            ],
            modelStyle: configuration.modelStyle,
            statusHandler: statusHandler
        )

        self.session = session
        self.uiState = .started(session)
    }

    /// Resets the conversation state
    /// Cancels any ongoing processing and resets states to idle
    private func resetConversationState() {
        Task {
            switch aiHumanState {
            case .speaking:
                processingState = .idle
                await stopSpeech?()
            default:
                if processingState == .stt || processingState == .llm {
                    processingTask?.cancel()
                }
            }
        }
    }

    /// Starts audio recording
    private func _startRecording() {
        Task {
            do {
                try await recorder.startRecording()
                startRecording?()
            } catch {
                debugPrint("failed to start recording \(error)")
            }
        }
    }

    /// Stops audio recording and processes the recorded audio
    private func stopRecording() {
        processingTask?.cancel()
        processingTask = Task { [weak self] in
            guard let self else { return }

            do {
                let data = try await self.recorder.stopRecording()
                await processConversation(audio: data)
            } catch {
                debugPrint("recording error: \(error)")
            }
        }
    }

    /// Processes voice input through STT then LLM
    /// - Parameter audio: The recorded audio data
    private func processConversation(audio: Data) async {
        guard let session else { return }

        do {
            processingState = .stt

            // STEP 1: Transcribe audio to text using SDK's STT
            let userText = try await session.transcribeAudio(audio: audio)

            // Add user message to chat history
            let userMessage: ChatMessage = .user(userText)
            messages.append(userMessage)

            // STEP 2: Continue with LLM processing
            await processConversation(message: userText)
        } catch PersoInteractiveError.taskCancelled {
            debugPrint("STT task cancelled")
            chatResponseState = .idle
            processingState = .idle
        } catch {
            debugPrint("STT conversation error: \(error)")
            chatResponseState = .error("Speech recognition failed. Please try again.")
            processingState = .idle
        }

        processingTask = nil
    }

    /// Processes a text message through the LLM and handles streaming responses
    /// - Parameter message: The user's message
    private func processConversation(message: String) async {
        guard let session else { return }

        do {
            // Only set processingState to .llm if it's not already set (for follow-up calls)
            if processingState != .llm {
                processingState = .llm
            }
            chatResponseState = .waiting
            streamingResponse = ""

            // STEP 1: Send message to LLM and get streaming response
            let stream = session.completeChat(
                message: .init(content: message),
                tools: [
                    WeatherTool(),
                ]
            )

            var isFirstChunk = true

            // STEP 2: Process streaming response chunks
            for try await partial in stream {
                switch partial {
                case .assistant(let assistantMessage, let finish):
                    // Handle TTS in real-time for each chunk (during streaming)
                    if !finish, let chunk = assistantMessage.chunks.last {
                        if isFirstChunk {
                            chatResponseState = .streaming
                            isFirstChunk = false
                        }
                        streamingResponse += chunk
                        handleAssistantMessage(chunk)
                    }

                    // Add completed message to UI when streaming finishes
                    if finish {
                        messages.append(partial)
                        streamingResponse = ""
                        chatResponseState = .idle
                        processingState = .idle
                    }
                default:
                    continue
                }
            }

            processingState = .idle

        } catch PersoInteractiveError.largeLanguageModelStreamingResponseError(let reason) {
            /// If a failure occurs during the LLM stream, display the message up to the processed portion.
            debugPrint("LLM Streaming Error: - \(reason)")
            chatResponseState = .error("An error occurred during response streaming.")
            processingState = .idle
        } catch PersoInteractiveError.taskCancelled {
            debugPrint("LLM Task Cancelled")
            chatResponseState = .idle
            processingState = .idle
        } catch {
            debugPrint("LLM conversation error: - \(error.localizedDescription)")
            chatResponseState = .error("An error occurred while processing the response. Please try again.")
            processingState = .idle
        }

        processingTask = nil
    }
}
