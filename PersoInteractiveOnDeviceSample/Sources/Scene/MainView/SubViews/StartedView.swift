//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import SwiftUI

import PersoInteractiveOnDeviceSDK

struct StartedView: View {
    let session: PersoInteractiveSession
    let geometry: GeometryProxy

    @State private var orientation: ViewOrientation = .unowned

    @EnvironmentObject var viewModel: MainViewModel

    enum ViewOrientation {
        case portrait
        case landscape
        case unowned
    }

    var body: some View {
        contentView
            .onAppear {
                orientation = geometry.size.width > geometry.size.height ? .landscape : .portrait
            }
            .onChange(of: geometry.size) { _, newSize in
                orientation = newSize.width > newSize.height ? .landscape : .portrait
            }
    }

#if os(macOS)
    private var contentView: some View {
        HSplitView {
            PersoInteractiveVideoViewRepresentable(session: session)
                .environmentObject(viewModel)
                .ignoresSafeArea(.all)
                .overlay(alignment: .bottomTrailing) {
                    if orientation == .portrait {
                        chatView
                            .frame(width: geometry.size.width * 0.4, height: geometry.size.height * 0.5 )
                            .allowsHitTesting(true)
                    }
                }

            if orientation == .landscape {
                chatView
                    .frame(width: geometry.size.width * 0.35)
            }
        }
    }
#else
    private var contentView: some View {
        HStack {
            PersoInteractiveVideoViewRepresentable(session: session)
                .environmentObject(viewModel)
                .ignoresSafeArea(.all)
                .overlay(alignment: .bottomTrailing) {
                    if orientation == .portrait {
                        chatView
                            .frame(width: geometry.size.width * 0.4, height: geometry.size.height * 0.5 )
                            .allowsHitTesting(true)
                    }
                }

            if orientation == .landscape {
                chatView
                    .frame(width: geometry.size.width * 0.35)
            }
        }
    }
#endif

    private var chatView: some View {
        ChatView()
            .background(.clear)
            .environmentObject(viewModel)
    }
}


