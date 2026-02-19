//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

#if os(iOS) || os(visionOS)
import UIKit
#endif
import SwiftUI

import PersoInteractiveOnDeviceSDK

struct ChatBubbleView: View {

    let message: ChatMessage

    private var isUser: Bool {
        message.role == .user
    }

    private var bubbleCornerRadius: CGFloat {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone ? 12 : 20
        #else
        20
        #endif
    }

    var body: some View {
        if let content = message.content {
            Text(content)
                .font(.system(size: 24, weight: .regular))
                .textSelection(.disabled)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(10)
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .foregroundStyle(isUser ? .black : .white)
                .background(isUser ? Color._0XF3F3F1 : Color._0X1C1C1E)
                .clipShape(RoundedRectangle(cornerRadius: bubbleCornerRadius, style: .continuous))
                #if os(iOS) || os(visionOS)
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = message.content ?? ""
                    }) {
                        Text("Copy")
                        Image(systemName: "square.on.square")
                    }
                }
                #endif
        } else {
            EmptyView()
        }
    }
}
