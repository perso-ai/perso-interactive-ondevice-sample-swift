//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

#if os(iOS) || os(visionOS)
import UIKit
#endif
import SwiftUI

import PersoInteractiveOnDeviceSDK

struct ChatView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: MainViewModel
    @State private var newMessage: String = ""
    @State private var isTypingMessage: Bool = false
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
            .onTapGesture {
                isTextFieldFocused = false
            }
        }
    }

    private var messagesContent: some View {
        VStack(alignment: .leading, spacing: 40) {
            ForEach(viewModel.messages.filter { message in
                message.role != .tool &&
                (message.role == .user || (message.role == .assistant && message.content != nil && !message.content!.isEmpty))
            }) { message in
                messageRow(for: message)
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
        guard !viewModel.isRecording else { return }  // 녹음 중이 아닐 때
        guard viewModel.aiHumanState != .speaking else { return }  // AI가 말하고 있지 않을 때
        guard viewModel.processingState == .idle else { return } // 처리 중이 아닐 때

        viewModel.sendMessage(newMessage)
        newMessage = ""
    }

    private var messageInputView: some View {
        HStack {
            /// TextField의 prompt에 foregroundStyle 를 설정하게 되면, macOS에서 적용되지 않는 문제
            ZStack(alignment: .leading) {
                if newMessage.isEmpty {
                    Text("메시지를 입력해 주세요.")
                        .foregroundStyle(._0XB6B6B6)
                        .font(.system(size: 24))
                }

                TextField("", text: $newMessage)
                    .textFieldStyle(.plain)
                    .focused($isTextFieldFocused)
                    .padding(.vertical)
                    .foregroundStyle(.black)
                    .font(.system(size: 24))
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .onSubmit(sendMessage)
                    .onChange(of: newMessage) { oldValue, newValue in
                        let isTyping = !newValue.isEmpty
                        if isTypingMessage != isTyping {
                            withAnimation {
                                isTypingMessage = isTyping
                            }
                        }
                    }
            }

            if !newMessage.isEmpty {
                Button(action: sendMessage) {
                    Image(.sendMessage)
                        .resizable()
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.white, ._0X1C1C1E)
                        .symbolVariant(.fill.circle)
                        .symbolEffect(.bounce, value: isTypingMessage)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Capsule(style: .continuous).fill(._0XF3F3F1))
    }
}



