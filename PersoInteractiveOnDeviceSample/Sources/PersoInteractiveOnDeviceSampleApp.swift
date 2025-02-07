//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import SwiftUI

import PersoInteractiveOnDeviceSDK

// MARK: - Main App

@main
struct PersoInteractiveOnDeviceSampleApp: App {

    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    init() {
        // Configure the SDK before the app launches
        configureSDK()
    }

    var body: some Scene {
        WindowGroup {
            rootView
        }
        // Platform-specific window configurations
        #if os(macOS)
        .defaultSize(
            width: PlatformConfig.current.defaultSize.width,
            height: PlatformConfig.current.defaultSize.height
        )
        .windowStyle(.hiddenTitleBar)
        #elseif os(visionOS)
        .windowStyle(.plain)
        .defaultSize(.init(
            width: PlatformConfig.current.defaultSize.width,
            height: PlatformConfig.current.defaultSize.height
        ))
        #endif
    }

    // MARK: - SDK Configuration

    /// Configures the Perso Interactive SDK with required settings
    /// This must be called before any SDK features are used
    private func configureSDK() {
        // STEP 1: Set your API key (required)
        // You can obtain your API key from the developer portal
        PersoInteractive.apiKey = <#T##String#>

        // STEP 2: Configure compute units (optional)
        // .ane - Uses Apple Neural Engine for optimal performance
        // .cpu - Uses CPU only (fallback option)
        PersoInteractive.computeUnits = .ane
    }

    // MARK: - Root View

    /// Returns the appropriate root view based on the platform
    private var rootView: some View {
        #if os(macOS)
        ContentView()
            .preferredColorScheme(.light)
        #else
        ContentView()
        #endif
    }
}

// MARK: - macOS AppDelegate

#if os(macOS)
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Return true to trigger applicationWillTerminate when the last window closes
        return true
    }
}
#endif
