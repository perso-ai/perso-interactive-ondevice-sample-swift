//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import Foundation

#if os(macOS)
import AppKit
#endif

// MARK: - Platform Configuration

/// Configuration struct providing platform-specific window and UI settings
struct PlatformConfig {
    /// Minimum window size constraints
    struct WindowSize {
        let width: CGFloat
        let height: CGFloat
    }

    /// Default window size on app launch
    struct DefaultSize {
        let width: CGFloat
        let height: CGFloat
    }

    let minSize: WindowSize
    let defaultSize: DefaultSize
    let supportsFullScreen: Bool
    let hidesTitle: Bool

    // MARK: - Platform Defaults

    #if os(iOS)
    /// iOS configuration - no window constraints needed
    static let current = PlatformConfig(
        minSize: WindowSize(width: 0, height: 0),
        defaultSize: DefaultSize(width: 0, height: 0),
        supportsFullScreen: false,
        hidesTitle: false
    )
    #elseif os(macOS)
    /// macOS configuration - desktop window with fullscreen support
    static let current = PlatformConfig(
        minSize: WindowSize(width: 500, height: 500),
        defaultSize: DefaultSize(width: 1200, height: 800),
        supportsFullScreen: true,
        hidesTitle: true
    )
    #elseif os(visionOS)
    /// visionOS configuration - optimized for spatial computing
    static let current = PlatformConfig(
        minSize: WindowSize(width: 600, height: 800),
        defaultSize: DefaultSize(width: 600, height: 2200),
        supportsFullScreen: false,
        hidesTitle: false
    )
    #endif
}
