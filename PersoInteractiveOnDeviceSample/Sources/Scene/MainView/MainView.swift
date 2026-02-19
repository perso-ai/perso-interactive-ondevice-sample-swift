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
        }
        .navigationBarBackButtonHidden()
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
