//
//  Copyright © 2025 ESTsoft. All rights reserved.

import Foundation

import PersoInteractiveOnDeviceSDK

extension ChatMessage {
    /// Gets the content of the message if available
    var content: String? {
        switch self {
        case .user(let message): return message.content
        case .assistant(let message, _): return message.content
        case .tool(let message): return message.content
        }
    }
}
