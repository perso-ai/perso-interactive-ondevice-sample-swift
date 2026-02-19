//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import SwiftUI

import PersoInteractiveOnDeviceSDK

struct ErrorView: View {
    let errorMessage: String
    let retryAction: () -> Void
    let backAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Error")
                .font(.title3.bold())
                .foregroundStyle(.white)

            Text(errorMessage)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button(action: retryAction) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color._0X644AFF, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: backAction) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back to Models")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
