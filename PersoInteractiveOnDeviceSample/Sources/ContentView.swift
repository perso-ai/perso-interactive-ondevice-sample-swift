//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import SwiftUI

import PersoInteractiveOnDeviceSDK

enum Screen: Hashable {
    case modelSelect
    case quickStart
    case main(SessionConfiguration)
}

struct ContentView: View {

    @State private var path: [Screen] = []

    var body: some View {
        NavigationStack(path: $path) {
            RunModeSelectView(path: $path)
                .navigationDestination(for: Screen.self) { screen in
                    switch screen {
                    case .modelSelect:
                        ModelSelectView(path: $path)
                    case .quickStart:
                        QuickStartView(path: $path)
                    case .main(let configuration):
                        MainView(path: $path, configuration: configuration)
                    }
                }
        }
    }
}
