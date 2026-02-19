//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

#if os(iOS) || os(visionOS)
import UIKit
#endif
import SwiftUI

import PersoInteractiveOnDeviceSDK

struct ChatView: View {

    @EnvironmentObject private var viewModel: MainViewModel
    @State private var newMessage: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: .zero) {
            messagesScrollView
            messageInputView
        }
        .padding()
        .background(.clear)
    }

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                messagesContent
            }
            .padding(.bottom)
            .scrollIndicators(.never)
            .defaultScrollAnchor(.bottom)
            .onChange(of: viewModel.messages) { oldValue, newValue in
                guard let lastItemID = newValue.last?.id else { return }

                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(lastItemID, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.streamingResponse) { _, _ in
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("streamingBubble", anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.chatResponseState) { _, newState in
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.25)) {
                        switch newState {
                        case .waiting:
                            proxy.scrollTo("typingIndicator", anchor: .bottom)
                        case .streaming:
                            proxy.scrollTo("streamingBubble", anchor: .bottom)
                        case .error:
                            proxy.scrollTo("errorBubble", anchor: .bottom)
                        case .idle:
                            if let lastID = viewModel.messages.last?.id {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .onTapGesture {
                isTextFieldFocused = false
            }
        }
    }

    private var messagesContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(viewModel.messages.filter { message in
                message.role != .tool &&
                (message.role == .user || (message.role == .assistant && message.content != nil && !message.content!.isEmpty))
            }) { message in
                messageRow(for: message)
            }

            // Typing indicator when waiting
            if viewModel.chatResponseState == .waiting {
                TypingIndicatorView()
                    .id("typingIndicator")
            }

            // Streaming response bubble
            if viewModel.chatResponseState == .streaming,
               !viewModel.streamingResponse.isEmpty {
                HStack(alignment: .bottom, spacing: 12) {
                    StreamingBubbleView(text: viewModel.streamingResponse)
                        .padding(.trailing)
                    Spacer(minLength: 0)
                }
                .id("streamingBubble")
            }

            // Error bubble
            if case .error(let errorMessage) = viewModel.chatResponseState {
                ChatErrorBubbleView(message: errorMessage) {
                    viewModel.retryLastMessage()
                }
                .id("errorBubble")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func messageRow(for message: ChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 0)
                ChatBubbleView(message: message)
                    .padding(.leading)
            } else if message.role == .assistant {
                ChatBubbleView(message: message)
                    .padding(.trailing)
                Spacer(minLength: 0)
            }
        }
    }

    private func sendMessage() {
        guard !newMessage.isEmpty else { return }
        guard !viewModel.isRecording else { return }

        viewModel.sendMessage(newMessage)
        newMessage = ""
    }

    private var messageInputView: some View {
        HStack {
            /// Workaround: foregroundStyle on TextField prompt doesn't apply on macOS
            ZStack(alignment: .leading) {
                if newMessage.isEmpty {
                    Text("Type a message...")
                        .foregroundStyle(._0XB6B6B6)
                        .font(.system(size: 20))
                        .padding(.leading, 4)
                }

                TextField("", text: $newMessage)
                    .textFieldStyle(.plain)
                    .focused($isTextFieldFocused)
                    .padding(.vertical, 8)
                    .foregroundStyle(.black)
                    .font(.system(size: 24))
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .onSubmit(sendMessage)
            }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white, newMessage.isEmpty ? Color._0XB6B6B6 : Color._0X1C1C1E)
            }
            .buttonStyle(.plain)
            .disabled(newMessage.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Capsule(style: .continuous).fill(._0XF3F3F1))
    }
}

// MARK: - Corner Radius Helper

private var chatBubbleCornerRadius: CGFloat {
    #if os(iOS) || os(visionOS)
    UIDevice.current.userInterfaceIdiom == .phone ? 12 : 20
    #else
    20
    #endif
}

private var chatRetryCornerRadius: CGFloat {
    #if os(iOS) || os(visionOS)
    UIDevice.current.userInterfaceIdiom == .phone ? 8 : 12
    #else
    12
    #endif
}

// MARK: - Streaming Bubble

private struct StreamingBubbleView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 24, weight: .regular))
            .textSelection(.disabled)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(10)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .foregroundStyle(.white)
            .background(Color._0X1C1C1E)
            .clipShape(RoundedRectangle(cornerRadius: chatBubbleCornerRadius, style: .continuous))
    }
}

// MARK: - Typing Indicator

private struct TypingIndicatorView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 12, height: 12)
                    .offset(y: animating ? -6 : 0)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 24)
        .background(Color._0X1C1C1E)
        .clipShape(RoundedRectangle(cornerRadius: chatBubbleCornerRadius, style: .continuous))
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Error Bubble

private struct ChatErrorBubbleView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.white)
                    .font(.system(size: 18))

                Text(message)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onRetry) {
                Text("Retry")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: chatRetryCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(Color.red.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: chatBubbleCornerRadius, style: .continuous))
    }
}
