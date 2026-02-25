//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import SwiftUI

import PersoInteractiveOnDeviceSDK

struct RunModeSelectView: View {

    @Binding var path: [Screen]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            headerView

            Spacer()
                .frame(height: 8)

            modeCardsView

            Spacer()
        }
        .padding(.horizontal, 24)
        .navigationBarBackButtonHidden()
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Perso Interactive")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("On-Device AI Session")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var modeCardsView: some View {
        VStack(spacing: 12) {
            modeCard(
                icon: "slider.horizontal.3",
                iconColor: Color._0X644AFF,
                title: "Manual Setup",
                description: "Select a model and configure the session pipeline manually"
            ) {
                path.append(.modelSelect)
            }

            modeCard(
                icon: "bolt.fill",
                iconColor: .orange,
                title: "Quick Start",
                description: "Start a session instantly with code-defined defaults"
            ) {
                path.append(.quickStart)
            }
        }
    }

    private func modeCard(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
