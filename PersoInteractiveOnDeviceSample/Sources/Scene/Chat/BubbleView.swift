//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

#if os(iOS) || os(visionOS)
import UIKit
#endif
import SwiftUI

struct BubbleView: View {

    enum Style {
        case user
        case assistant
    }

    let text: String
    let style: Style
    let showContextMenu: Bool

    init(text: String, style: Style, showContextMenu: Bool = true) {
        self.text = text
        self.style = style
        self.showContextMenu = showContextMenu
    }

    private var foregroundColor: Color {
        style == .user ? .black : .white
    }

    private var backgroundColor: Color {
        style == .user ? Color._0XF3F3F1 : Color._0X1C1C1E
    }

    private var bubbleCornerRadius: CGFloat {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone ? 12 : 20
        #else
        20
        #endif
    }

    var body: some View {
        #if os(iOS) || os(visionOS)
        if showContextMenu {
            bubbleText
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = text
                    }) {
                        Text("Copy")
                        Image(systemName: "square.on.square")
                    }
                }
        } else {
            bubbleText
        }
        #else
        bubbleText
        #endif
    }

    private var bubbleText: some View {
        Text(text)
            .font(.system(size: 24, weight: .regular))
            .textSelection(.disabled)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(10)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: bubbleCornerRadius, style: .continuous))
    }
}
