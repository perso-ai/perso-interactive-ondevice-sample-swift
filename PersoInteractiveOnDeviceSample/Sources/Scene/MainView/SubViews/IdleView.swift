//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import SwiftUI

struct IdleView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.01)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Circle()
                    .stroke(lineWidth: 5)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .trim(from: 0, to: 0.6)
                            .stroke(style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(isAnimating ? 360 : 0))
                            .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                    )


                Text("Loading...")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}
