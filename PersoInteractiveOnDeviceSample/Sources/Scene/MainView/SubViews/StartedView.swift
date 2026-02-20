//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

#if os(iOS)
import UIKit
#endif
import SwiftUI

import PersoInteractiveOnDeviceSDK

struct StartedView: View {
    let session: PersoInteractiveSession
    let geometry: GeometryProxy

    @State private var orientation: ViewOrientation = .unknown

    @Environment(MainViewModel.self) var viewModel

    #if os(iOS)
    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    #endif

    enum ViewOrientation {
        case portrait
        case landscape
        case unknown
    }

    var body: some View {
        contentView
            .onAppear {
                orientation = geometry.size.width > geometry.size.height ? .landscape : .portrait
            }
            .onChange(of: geometry.size) { _, newSize in
                orientation = newSize.width > newSize.height ? .landscape : .portrait
            }
    }

#if os(macOS)
    private var contentView: some View {
        HSplitView {
            PersoInteractiveVideoViewRepresentable(session: session)
                .environment(viewModel)
                .ignoresSafeArea(.all)
                .overlay(alignment: .bottomLeading) {
                    controlButtons
                        .padding(.leading, 40)
                        .padding(.bottom, 40)
                }
                .overlay(alignment: .bottomTrailing) {
                    if orientation == .portrait {
                        chatView
                            .frame(width: geometry.size.width * 0.4, height: geometry.size.height * 0.5 )
                            .allowsHitTesting(true)
                    }
                }

            if orientation == .landscape {
                chatView
                    .frame(width: geometry.size.width * 0.35)
            }
        }
    }
#else
    private var contentView: some View {
        Group {
            if isPhone {
                phoneContentView
            } else {
                padContentView
            }
        }
    }

    // MARK: - iPhone Layout (Full-Screen Chat Overlay)

    private var phoneContentView: some View {
        PersoInteractiveVideoViewRepresentable(session: session)
            .environment(viewModel)
            .ignoresSafeArea(.all)
            .overlay(alignment: .bottomLeading) {
                if !viewModel.isChatHistoryVisible {
                    controlButtons
                        .padding(.leading, 40)
                        .padding(.bottom, 40)
                }
            }
            .overlay {
                if viewModel.isChatHistoryVisible {
                    VStack(spacing: 0) {
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    viewModel.isChatHistoryVisible = false
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.white.opacity(0.9), .white.opacity(0.2))
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 16)
                            .padding(.top, 8)
                        }
                        chatView
                    }
                    .background(.ultraThinMaterial)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.isChatHistoryVisible)
    }

    // MARK: - iPad Layout (Existing Overlay/Sidebar)

    private var padContentView: some View {
        HStack {
            PersoInteractiveVideoViewRepresentable(session: session)
                .environment(viewModel)
                .ignoresSafeArea(.all)
                .overlay(alignment: .bottomLeading) {
                    controlButtons
                        .padding(.leading, 40)
                        .padding(.bottom, 40)
                }
                .overlay(alignment: .bottomTrailing) {
                    if orientation == .portrait && viewModel.isChatHistoryVisible {
                        chatView
                            .frame(width: geometry.size.width * 0.4, height: geometry.size.height * 0.5 )
                            .allowsHitTesting(true)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.isChatHistoryVisible)

            if orientation == .landscape && viewModel.isChatHistoryVisible {
                chatView
                    .frame(width: geometry.size.width * 0.35)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isChatHistoryVisible)
    }
#endif

    // MARK: - Control Buttons

    private var controlButtons: some View {
        VStack(alignment: .center, spacing: 24) {
            primaryControlButton
            sessionRestartButton
            #if os(iOS)
            chatToggleButton
            #endif
        }
    }

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

    private var sessionRestartButton: some View {
        ControlButton(
            type: .normal("arrow.counterclockwise")
        ) {
            viewModel.restartSession()
        }
    }

    #if os(iOS)
    private var chatToggleButton: some View {
        ControlButton(
            type: .normal(viewModel.isChatHistoryVisible ? "text.bubble.fill" : "text.bubble")
        ) {
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.isChatHistoryVisible.toggle()
            }
        }
    }
    #endif

    private var chatView: some View {
        ChatView()
            .background(.clear)
            .environment(viewModel)
    }
}


