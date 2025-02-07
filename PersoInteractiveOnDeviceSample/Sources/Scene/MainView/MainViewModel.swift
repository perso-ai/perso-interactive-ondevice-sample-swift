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

    /// The selected model style for the session
    private var modelStyle: ModelStyle

    /// Current backend processing state
    @Published var processingState: ProcessingState = .idle

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

    // Available SDK features (fetched from the SDK)
    private var availableSTTTypes: [STTType] = []
    private var availableLLMTypes: [LLMType] = []
    private var availablePrompts: [Prompt] = []
    private var availableDocuments: [Document] = []
    private var availableTTSTypes: [TTSType] = []
    private var availableMCPServers: [MCPServer] = []

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
        processingTask?.cancel()
    }

    init(modelStyle: ModelStyle) {
        self.modelStyle = modelStyle

        Task {
            do {
                // STEP 1: Load the SDK (prepares models and resources)
                try await PersoInteractive.load()

                // STEP 2: Warmup the SDK (optimizes for first use)
                try await PersoInteractive.warmup()

                // STEP 3: Initialize a new session
                await initializeSession()

                // STEP 4: Bind UI state to properties
                bind()
            } catch {
                uiState = .error("initialization occured an error: \(error).\nPlease try again.")
            }
        }
    }

    // MARK: - Public Methods

    /// Initializes or reinitializes the chat session
    /// This demonstrates the complete SDK session setup flow
    func initializeSession() async {
        uiState = .idle
        aiHumanState = .idle
        processingState = .idle

        clearHistory()

        do {
            // Fetch available SDK features (models, prompts, etc.)
            try await fetchAvailableFeatures()

            // Create a new session with selected features
            try await createSession()
        } catch {
            uiState = .error("Unable to create session: \(error.localizedDescription)")
        }
    }

    /// Sends a text message to the LLM
    /// - Parameter message: The user's text message
    func sendMessage(_ message: String) {
        let userMessage: ChatMessage = .user(message)
        messages.append(userMessage)

        processingTask = Task { [weak self] in
            await self?.processConversation(message: message)
        }
    }

    /// Sets the callback for handling assistant message chunks
    /// - Parameter callback: Function to handle each message chunk
    func handleAssistantMessage(_ callback: @escaping (String) -> Void) {
        handleAssistantMessage = callback
    }

    /// Stops the current session
    func stopSession() {
        PersoInteractive.stopSession()
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
        self.aiHumanState = state
    }
}

// MARK: - Private Methods

extension MainViewModel {
    /// Binds recorder state to view model properties
    private func bind() {
        recorder.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                self?.isRecording = isRecording
            }
            .store(in: &cancellables)
    }

    /// Fetches all available SDK features in parallel
    /// This demonstrates how to query the SDK for available models and resources
    private func fetchAvailableFeatures() async throws {
        async let sttTypes = PersoInteractive.fetchAvailableSTTModels()
        async let llmTypes = PersoInteractive.fetchAvailableLLMModels()
        async let prompts = PersoInteractive.fetchAvailablePrompts()
        async let documents = PersoInteractive.fetchAvailableDocuments()
        async let ttsTypes = PersoInteractive.fetchAvailableTTSModels()
        async let mcpServers = PersoInteractive.fetchAvailableMCPServers()

        (availableSTTTypes, availableLLMTypes, availablePrompts, availableDocuments, availableTTSTypes, availableMCPServers) = try await (
            sttTypes, llmTypes, prompts, documents, ttsTypes, mcpServers
        )
    }

    /// Creates a new session with selected features
    /// This demonstrates how to configure a session with STT, LLM, and TTS capabilities
    private func createSession() async throws {
        // Select features to use (using first available for simplicity)
        let sttType = availableSTTTypes[0]
        let llmType = availableLLMTypes[0]
        let prompt = availablePrompts[0]
        let document = availableDocuments.first
        let ttsType = availableTTSTypes[0]
        let mcpServers = availableMCPServers

        // IMPORTANT: Create session with selected capabilities
        // The order matters: STT -> LLM -> TTS represents the processing pipeline
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
            modelStyle: modelStyle
        ) { [weak self] sessionStatus in
            guard let self else { return }

            // Monitor session lifecycle
            switch sessionStatus {
            case .started:
                break
            case .terminated:
                self.session = nil
                Task { @MainActor in
                    self.uiState = .terminated
                }
            default:
                break
            }
        }

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
            processingState = .idle
        } catch {
            debugPrint("STT conversation error")
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

            // STEP 1: Send message to LLM and get streaming response
            let stream = session.completeChat(
                message: .init(content: message),
                tools: [
                    WeatherTool(),
                ]
            )

            // STEP 2: Process streaming response chunks
            for try await partial in stream {
                switch partial {
                case .assistant(let assistantMessage, let finish):
                    // Handle TTS in real-time for each chunk (during streaming)
                    if !finish, let chunk = assistantMessage.chunks.last {
                        handleAssistantMessage(chunk)
                    }

                    // Add completed message to UI when streaming finishes
                    if finish {
                        messages.append(partial)
                    }
                default:
                    continue
                }
            }

        } catch PersoInteractiveError.largeLanguageModelStreamingResponseError(let reason) {
            /// If a failure occurs during the LLM stream, display the message up to the processed portion.
            debugPrint("LLM Streaming Error: - \(reason)")
            processingState = .idle
        } catch PersoInteractiveError.taskCancelled {
            debugPrint("LLM Task Cancelled")
            processingState = .idle
        } catch {
            debugPrint("LLM conversation error: - \(error.localizedDescription)")
            processingState = .idle
        }

        processingTask = nil
    }
}
