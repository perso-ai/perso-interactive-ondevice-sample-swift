//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import SwiftUI

import PersoInteractiveOnDeviceSDK

// MARK: - Platform Compatibility

#if os(iOS) || os(visionOS)
typealias ViewRepresentable = UIViewRepresentable
#elseif os(macOS)
typealias ViewRepresentable = NSViewRepresentable
#endif

// MARK: - PersoInteractiveVideoView Wrapper

/// SwiftUI wrapper for the SDK's PersoInteractiveVideoView
/// This demonstrates how to embed the native video view in SwiftUI
struct PersoInteractiveVideoViewRepresentable: ViewRepresentable {
    @EnvironmentObject var viewModel: MainViewModel

    /// The session that provides video rendering
    private let session: PersoInteractiveSession

    init(session: PersoInteractiveSession) {
        self.session = session
    }

    // MARK: - iOS/visionOS Implementation

#if os(iOS) || os(visionOS)
    func makeUIView(context: Context) -> PersoInteractiveVideoView {
        // STEP 1: Create PersoInteractiveVideoView with session
        let persoVideoView = PersoInteractiveVideoView(session: session)

        // STEP 2: Set delegate to receive state changes
        persoVideoView.delegate = context.coordinator

        // STEP 3: Configure view and start playback
        setupView(persoVideoView)
        return persoVideoView
    }

    func updateUIView(_ view: PersoInteractiveVideoView, context: Context) {}

    // MARK: - macOS Implementation

#elseif os(macOS)
    func makeNSView(context: Context) -> PersoInteractiveVideoView {
        // STEP 1: Create PersoInteractiveVideoView with session
        let videoView = PersoInteractiveVideoView(session: session)

        // STEP 2: Configure video aspect ratio (1.0 = fill height)
        videoView.contentHeightFactor = 1.0

        // STEP 3: Set delegate to receive state changes
        videoView.delegate = context.coordinator

        // STEP 4: Configure view and start playback
        setupView(videoView)
        return videoView
    }

    func updateNSView(_ view: PersoInteractiveVideoView, context: Context) {}
#endif

    // MARK: - View Setup

    /// Configures the video view and sets up callbacks
    /// This demonstrates the complete flow of initializing and using PersoInteractiveVideoView
    @MainActor
    private func setupView(_ videoView: PersoInteractiveVideoView) {
        // STEP 1: Start video from initial state (.idle)
        // This begins the video rendering pipeline
        try? videoView.start(from: .idle)

        // STEP 2: Play intro animation (optional welcome message)
        // The completion handler receives the intro message text
        videoView.playIntro { message in
            Task { @MainActor in
                // Transition video to speaking state
                try? await videoView.transition(to: .transition)
                viewModel.processingState = .llm

                // Add intro message to chat history
                viewModel.messages.append(.assistant(message))
            }
        }

        // STEP 3: Set up speech stopping callback
        // This allows the app to interrupt ongoing speech
        viewModel.stopSpeech = { [weak videoView] in
            await videoView?.stopSpeech()
        }

        // STEP 4: Set up recording start callback
        // Transitions video to listening state when recording starts
        viewModel.startRecording = { [weak videoView] in
            Task { @MainActor in
                if viewModel.aiHumanState == .idle {
                    try? await videoView?.transition(to: .transition)
                }
            }
        }

        // STEP 5: Handle assistant message chunks for TTS
        // Push text chunks to the video view for real-time speech synthesis
        viewModel.handleAssistantMessage { message in
            do {
                // IMPORTANT: Push text to video view for TTS playback
                // The video view will animate the AI human while speaking
                try videoView.push(text: message)
            } catch {
                print("session terminated \(error)")
            }
        }
    }
}

// MARK: - Coordinator

extension PersoInteractiveVideoViewRepresentable {

    /// Coordinator handles PersoInteractiveVideoView delegate callbacks
    /// This demonstrates how to monitor video state changes
    class Coordinator: NSObject, PersoInteractiveVideoViewDelegate {
        private let viewModel: MainViewModel

        init(_ viewModel: MainViewModel) {
            self.viewModel = viewModel
        }

        /// Called when an error occurs in the video view
        /// - Parameter error: The error that occurred
        func persoInteractiveVideoView(didFailWithError error: PersoInteractiveError) {
            debugPrint("persoVideoView error: \(error)")
        }

        /// Called when the video state changes
        /// This allows you to sync UI state with the AI human's state
        /// - Parameter state: The new video state
        func persoInteractiveVideoView(didChangeState state: PersoInteractiveVideoView.VideoState) {
            debugPrint("persoVideoView didChangeState: \(state)")

            Task {
                await MainActor.run { [weak self] in
                    switch state {
                    case .waiting(let phase):
                        // Video is in waiting/idle state
                        switch phase {
                        case .idle:
                            // AI human is completely idle
                            self?.viewModel.updateHumanState(.idle)
                        case .transition:
                            // AI human is transitioning between states
                            self?.viewModel.updateHumanState(.transition)
                        case .standby:
                            // AI human is ready to speak
                            self?.viewModel.updateHumanState(.standby)
                        }
                    case .processing:
                        // AI human is currently speaking
                        self?.viewModel.updateHumanState(.speaking)
                    }
                }
            }
        }
    }

    /// Creates the coordinator for managing delegate callbacks
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel)
    }
}
