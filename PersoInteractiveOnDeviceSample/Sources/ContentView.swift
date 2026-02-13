//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import SwiftUI

import PersoInteractiveOnDeviceSDK

enum Screen: Hashable {
    case modelSelectView
    case configure(ModelStyle)
    case main(SessionConfiguration)
}

struct ContentView: View {

    @State private var path: [Screen] = []

    var body: some View {
        NavigationStack(path: $path) {
            ModelSelectView(path: $path)
                .navigationDestination(for: Screen.self) { screen in
                    switch screen {
                    case .modelSelectView:
                        ModelSelectView(path: $path)
                    case .configure(let modelStyle):
                        ConfigureView(path: $path, modelStyle: modelStyle)
                    case .main(let configuration):
                        MainView(path: $path, configuration: configuration)
                    }
                }
        }
    }
}
