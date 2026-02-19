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
    @State private var showEndSessionAlert = false

    // MARK: - Initialization

    init(path: Binding<[Screen]>, configuration: SessionConfiguration) {
        self._viewModel = .init(wrappedValue: .init(configuration: configuration))
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
                    IdleView(message: viewModel.loadingMessage)
                case .started(let session):
                    StartedView(session: session, geometry: geometry)
                        .environmentObject(viewModel)
                case .terminated:
                    TerminatedView(
                        retryAction: { Task { await viewModel.initializeSession() } },
                        backAction: { path.removeAll() }
                    )
                    .onAppear {
                        viewModel.clearHistory()
                    }
                case .error(let errorMessage):
                    ErrorView(
                        errorMessage: errorMessage,
                        retryAction: { Task { await viewModel.initializeSession() } },
                        backAction: { path.removeAll() }
                    )
                }
            }
            .background(
                BackgroundView()
            )
            .overlay(alignment: controlsAlignment) {
                controlsOverlay
            }
            .overlay(alignment: .topTrailing) {
                if viewModel.uiState.isStarted {
                    Button {
                        showEndSessionAlert = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white.opacity(0.9), .black.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
            }
            .alert("End Session", isPresented: $showEndSessionAlert) {
                Button("Cancel", role: .cancel) { }
                Button("End", role: .destructive) {
                    viewModel.stopSession()
                    path.removeAll()
                }
            } message: {
                Text("Are you sure you want to end this session?")
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorToast != nil },
                set: { if !$0 { viewModel.errorToast = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorToast ?? "")
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

    @ViewBuilder
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
                ZStack {
                    Circle()
                        .fill(Color._0X644AFF.opacity(0.5))
                        .frame(width: 64, height: 64)
                    ProgressView()
                        .tint(.white)
                        .controlSize(.regular)
                }
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
