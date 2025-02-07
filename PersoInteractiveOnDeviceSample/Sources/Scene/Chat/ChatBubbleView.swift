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

    var body: some View {
        if let content = message.content {
            Text(content)
                .font(.system(size: 24, weight: .semibold))
                .textSelection(.disabled)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(10)
                .padding(.vertical)
                .padding(.horizontal)
                .foregroundStyle(message.role == .user ? .black : .white)
                .background(message.role == .user ? .white : .gray)
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
