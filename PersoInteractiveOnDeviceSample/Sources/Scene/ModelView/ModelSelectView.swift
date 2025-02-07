//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import SwiftUI

import PersoInteractiveOnDeviceSDK

struct ModelSelectView: View {

    @Binding var path: [Screen]
    @StateObject private var viewModel: ModelSelectViewModel
    @State private var items: [ModelSelectView.Item] = []
    @State private var selectedItem: ModelSelectView.Item?

    init(path: Binding<[Screen]>) {
        self._path = path
        self._viewModel = .init(wrappedValue: .init())
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding()

            Divider()

            // Model List or Loading
            if items.isEmpty {
                loadingView
            } else {
                modelListView
            }
        }
        .task {
            await viewModel.fetchModelStyles()
        }
        .onChange(of: viewModel.models) { _, modelStyles in
            updateItems(with: modelStyles)
        }
        .onReceive(viewModel.modelStatusUpdated) { modelStyle in
            updateSelectedItem(with: modelStyle)
        }
        .onReceive(viewModel.moveToMainTabScreen) { modelStyle in
            path.append(.main(modelStyle))
        }
        .navigationBarBackButtonHidden()
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Available Models")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Select a model to download or use")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading available models...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var modelListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(items) { item in
                    ModelItemRow(
                        item: item,
                        isSelected: selectedItem?.id == item.id,
                        progress: viewModel.itemsProgress[item.id],
                        onTap: { selectItem(item) },
                        onAction: { viewModel.setItem(item) }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Private Methods

    private func updateItems(with modelStyles: [ModelStyle]) {
        items = modelStyles.map { modelStyle in
            if let existingItem = items.first(where: { $0.modelStyle == modelStyle }) {
                var updatedItem = existingItem
                updatedItem.modelStyle = modelStyle
                return updatedItem
            } else {
                return Item(modelStyle: modelStyle)
            }
        }

        if let selectedItem,
           let updatedSelectedItem = items.first(where: { $0.modelStyle == selectedItem.modelStyle }) {
            self.selectedItem = updatedSelectedItem
        }
    }

    private func updateSelectedItem(with modelStyle: ModelStyle) {
        // Update the item in the items array to trigger UI refresh
        if let index = items.firstIndex(where: { $0.modelStyle.name == modelStyle.name }) {
            var updatedItem = items[index]
            updatedItem.modelStyle = modelStyle
            items[index] = updatedItem
        }

        // Update selected item
        self.selectedItem = nil
        self.selectedItem = Item(modelStyle: modelStyle)
    }

    private func selectItem(_ item: ModelSelectView.Item) {
        selectedItem = item
    }
}

// MARK: - Model Item Row

private struct ModelItemRow: View {
    let item: ModelSelectView.Item
    let isSelected: Bool
    let progress: Progress?
    let onTap: () -> Void
    let onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                // Status Icon
                statusIcon
                    .frame(width: 32, height: 32)

                // Model Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.modelStyle.displayName ?? item.modelStyle.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(item.modelStyle.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    statusLabel
                }

                Spacer()

                // Action Button
                actionButton
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            // Progress View (if downloading)
            if let progress = progress {
                VStack(spacing: 8) {
                    ProgressView(value: progress.fractionCompleted)
                        .progressViewStyle(.linear)

                    HStack {
                        Text("Downloading...")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(formatBytes(progress.completedUnitCount)) / \(formatBytes(progress.totalUnitCount))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.modelStyle.availability {
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title2)

        case .unavailable(let reason):
            switch reason {
            case .notDownloaded:
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.blue)
                    .font(.title2)

            case .updateRequired:
                Image(systemName: "arrow.triangle.2.circlepath.circle")
                    .foregroundStyle(.orange)
                    .font(.title2)

            case .unknown:
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.gray)
                    .font(.title2)

            @unknown default:
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.red)
                    .font(.title2)
            }
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch item.modelStyle.availability {
        case .available:
            Text("Ready to use")
                .font(.caption)
                .foregroundStyle(.green)

        case .unavailable(let reason):
            switch reason {
            case .notDownloaded:
                Text("Not downloaded")
                    .font(.caption)
                    .foregroundStyle(.blue)

            case .updateRequired:
                Text("Update available")
                    .font(.caption)
                    .foregroundStyle(.orange)

            case .unknown:
                Text("Status unknown")
                    .font(.caption)
                    .foregroundStyle(.gray)

            @unknown default:
                Text("Error")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        Button(action: onAction) {
            HStack(spacing: 6) {
                actionIcon
                Text(actionTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(actionColor)
            .foregroundStyle(.white)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(progress != nil)
        .opacity(progress != nil ? 0.5 : 1.0)
    }

    private var actionTitle: String {
        switch item.modelStyle.availability {
        case .available:
            return "Load"
        case .unavailable(let reason):
            switch reason {
            case .notDownloaded:
                return "Download"
            case .updateRequired:
                return "Update"
            case .unknown:
                return "Download"
            @unknown default:
                return "Download"
            }
        }
    }

    @ViewBuilder
    private var actionIcon: some View {
        switch item.modelStyle.availability {
        case .available:
            Image(systemName: "play.fill")
        case .unavailable(let reason):
            switch reason {
            case .notDownloaded:
                Image(systemName: "arrow.down")
            case .updateRequired:
                Image(systemName: "arrow.clockwise")
            case .unknown, _:
                Image(systemName: "arrow.down")
            }
        }
    }

    private var actionColor: Color {
        switch item.modelStyle.availability {
        case .available:
            return .green
        case .unavailable(let reason):
            switch reason {
            case .notDownloaded:
                return .blue
            case .updateRequired:
                return .orange
            case .unknown, _:
                return .gray
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesActualByteCount = false
        return formatter.string(fromByteCount: bytes)
    }

    private var backgroundColor: Color {
        #if os(iOS) || os(visionOS)
        return Color(.systemGray6)
        #else
        return Color(nsColor: .windowBackgroundColor).opacity(0.5)
        #endif
    }
}

// MARK: - Extensions

extension ModelSelectView {
    struct Item: Identifiable {
        let id = UUID()
        var modelStyle: ModelStyle
        var isSelected: Bool = false
    }
}
