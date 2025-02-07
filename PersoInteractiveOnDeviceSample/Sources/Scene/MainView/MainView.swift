//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import AVFAudio
import SwiftUI

import PersoInteractiveOnDeviceSDK

struct MainView: View {

    // MARK: - Properties
    @Binding var path: [Screen]
    @StateObject private var viewModel: MainViewModel

    // MARK: - Initialization

    init(path: Binding<[Screen]>, modelStyle: ModelStyle) {
        self._viewModel = .init(wrappedValue: .init(modelStyle: modelStyle))
        self._path = path

#if os(iOS)
        try? PersoInteractive.setAudioSession(
            category: .playAndRecord,
            options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
        )
#endif
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                switch viewModel.uiState {
                case .idle:
                    IdleView()
                case .started(let session):
                    StartedView(session: session, geometry: geometry)
                        .environmentObject(viewModel)
                case .terminated:
                    TerminatedView {
                        Task { await viewModel.initializeSession() }
                    }
                    .onAppear {
                        viewModel.clearHistory()
                    }
                case .error(let errorMessage):
                    ErrorView(errorMessage: errorMessage) {
                        Task { await viewModel.initializeSession() }
                    }
                }
            }
            .background(
                BackgroundView()
            )
            .overlay(alignment: controlsAlignment) {
                controlsOverlay
            }
        }
        .navigationBarBackButtonHidden()
    }

    private var controlsOverlay: some View {
        VStack(alignment: .center, spacing: 24) {
            if viewModel.uiState.isStarted {
                primaryControlButton
                historyButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 40)
    }

    // MARK: - Control Buttons

    private var primaryControlButton: some View {
        switch viewModel.aiHumanState {
        case .idle, .transition:
            switch viewModel.processingState {
            case .idle:
                if viewModel.isRecording {
                    ControlButton(
                        type: .recording,
                        action: {
                            viewModel.recordStopButtonDidTap()
                        }
                    )
                } else {
                    ControlButton(
                        type: .normal("mic.fill"),
                        action: {
                            viewModel.recordButtonDidTap()
                        }
                    )
                }
            case .stt, .llm:
                ControlButton(
                    type: .normal("ellipsis"),
                    action: { }
                )
            }
        case .standby:
            switch viewModel.processingState {
            case .idle:
                if viewModel.isRecording {
                    ControlButton(
                        type: .recording,
                        action: {
                            viewModel.recordStopButtonDidTap()
                        }
                    )
                } else {
                    ControlButton(
                        type: .normal("mic.fill"),
                        action: {
                            viewModel.recordButtonDidTap()
                        }
                    )
                }
            case .stt, .llm:
                ControlButton(
                    type: .normal("pause"),
                    action: {
                        viewModel.stopSpeechButtonDidTap()
                    }
                )
            }
        case .speaking:
            ControlButton(
                type: .normal("pause"),
                action: {
                    viewModel.stopSpeechButtonDidTap()
                }
            )
        }
    }

    private var historyButton: some View {
        ControlButton(
            type: .normal("arrow.counterclockwise"),
            isEnabled: !viewModel.messages.isEmpty,
            action: {
                viewModel.clearHistory()
            }
        )
    }

    // MARK: - Platform-specific Configuration

    private var controlsAlignment: Alignment {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .bottomLeading
        }
        return .leading
        #else
        return .leading
        #endif
    }
}

// MARK: - Supporting Views

extension MainView {
    struct BackgroundView: View {
        var body: some View {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                Image(.background)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .opacity(0.4) // Slightly dimmed for better contrast with controls

                // Subtle gradient overlay for depth
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.3),
                        Color.clear,
                        Color.black.opacity(0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
    }
}
