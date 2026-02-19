//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import SwiftUI

/// Unified control button for all states
struct ControlButton: View {
    let type: ButtonType
    let action: () -> Void
    let isEnabled: Bool

    enum ButtonType {
        case normal(String)           // icon
        case recording                 // animated stop

        var icon: String? {
            switch self {
            case .normal(let icon):
                return icon
            case .recording:
                return nil
            }
        }

        var foregroundColor: Color {
            switch self {
            case .normal: return .white
            case .recording: return .white
            }
        }

        var backgroundColor: Color {
            switch self {
            case .normal: return ._0X644AFF
            case .recording: return .red.opacity(0.9)
            }
        }

    }

    init(
        type: ButtonType,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.type = type
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Background circle
                Circle()
                    .fill(type.backgroundColor)
                    .frame(width: 64, height: 64)

                // Content
                if case .recording = type {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .frame(width: 22, height: 22)
                } else if let icon = type.icon {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(type.foregroundColor)
                }

                // Gradient overlay for non-recording buttons
                if case .recording = type {
                    EmptyView()
                } else {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(Circle())
                    .frame(width: 64, height: 64)
                }
            }
            .scaleEffect(isEnabled ? 1.0 : 0.95)
            .opacity(isEnabled ? 1.0 : 0.5)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isEnabled)
    }
}

/// Custom button style that provides press feedback
struct PressableButtonStyle: SwiftUI.ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
