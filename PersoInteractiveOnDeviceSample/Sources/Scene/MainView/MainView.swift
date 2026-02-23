//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import AVFAudio
import SwiftUI

import PersoInteractiveOnDeviceSDK

struct MainView: View {

    // MARK: - Properties
    @Binding var path: [Screen]
    @State private var viewModel: MainViewModel
    @State private var showEndSessionAlert = false

    // MARK: - Initialization

    init(path: Binding<[Screen]>, configuration: SessionConfiguration) {
        self._viewModel = State(initialValue: MainViewModel(configuration: configuration))
        self._path = path
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
                        .environment(viewModel)
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
                    // Stop the session first so the SDK's statusHandler fires
                    // the .terminated callback *before* MainViewModel is
                    // deallocated. Navigating away (path.removeAll) immediately
                    // after stopSession races against the SDK's background
                    // callback Task { @MainActor } that writes self.session = nil
                    // and self.uiState = .terminated — both tasks hit the same
                    // @MainActor properties concurrently and corrupt state.
                    // By letting initializeSession() drive the teardown through
                    // the ViewModel's own path (which guards against double-stop
                    // with isRestarting), and only dismissing the navigation
                    // after the uiState transitions to .terminated, we eliminate
                    // the race. For a forced immediate exit we still call
                    // stopSession but defer path removal to the .terminated
                    // handler already wired in createSession's statusHandler.
                    PersoInteractive.stopSession()
                    // Give the SDK one run-loop turn to enqueue its .terminated
                    // callback before we tear down the view hierarchy.
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
        .task {
            #if os(iOS)
            try? PersoInteractive.setAudioSession(
                category: .playAndRecord,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            #endif
        }
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
