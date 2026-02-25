//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import SwiftUI
import PersoInteractiveOnDeviceSDK

struct QuickStartView: View {

    @Binding var path: [Screen]
    @State private var viewModel = QuickStartViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            switch viewModel.state {
            case .loading(let message):
                loadingContent(message: message)
            case .downloading(let model, let progress):
                downloadingContent(model: model, progress: progress)
            case .error(let message):
                errorContent(message: message)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarBackButtonHidden()
        .task {
            if let configuration = await viewModel.configure() {
                path.append(.main(configuration))
            }
        }
    }

    // MARK: - Loading

    private func loadingContent(message: String) -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
                .tint(Color._0X644AFF)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Downloading

    private func downloadingContent(model: ModelStyle, progress: Double) -> some View {
        VStack(spacing: 20) {
            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(.linear)
                .tint(Color._0X644AFF)
                .frame(maxWidth: 240)

            Text("\(Int(progress * 100))%")
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()
                .contentTransition(.numericText())

            Text("Downloading \(model.displayName ?? model.name)...")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                path.removeAll()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "xmark")
                    Text("Cancel")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.secondary.opacity(0.15))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    // MARK: - Error

    private func errorContent(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Quick Start Failed")
                .font(.title3)
                .fontWeight(.bold)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                path.removeAll()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left")
                    Text("Go Back")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color._0X644AFF)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}
