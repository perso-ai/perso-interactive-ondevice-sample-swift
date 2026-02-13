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
    @State private var showDeleteConfirmation = false

    init(path: Binding<[Screen]>) {
        self._path = path
        self._viewModel = .init(wrappedValue: .init())
    }

    private var downloadedItems: [Item] {
        items.filter { $0.modelStyle.availability == .available }
            .sorted { ($0.modelStyle.displayName ?? $0.modelStyle.name)
                .localizedCaseInsensitiveCompare($1.modelStyle.displayName ?? $1.modelStyle.name) == .orderedAscending }
    }

    private var notDownloadedItems: [Item] {
        items.filter { $0.modelStyle.availability != .available }
            .sorted { ($0.modelStyle.displayName ?? $0.modelStyle.name)
                .localizedCaseInsensitiveCompare($1.modelStyle.displayName ?? $1.modelStyle.name) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding()

            Divider()

            // Model List or Loading
            if viewModel.errorMessage != nil {
                errorView
            } else if viewModel.isLoading {
                loadingView
            } else {
                modelListView
            }
        }
        .task {
            await viewModel.fetchModelStyles()
        }
        .onReceive(viewModel.$models) { modelStyles in
            updateItems(with: modelStyles)
        }
        .onReceive(viewModel.modelStatusUpdated) { modelStyle in
            updateSelectedItem(with: modelStyle)
        }
        .onReceive(viewModel.moveToMainTabScreen) { modelStyle in
            path.append(.configure(modelStyle))
        }
        .navigationBarBackButtonHidden()
        .alert("Download Failed", isPresented: Binding(
            get: { viewModel.downloadError != nil },
            set: { if !$0 { viewModel.downloadError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.downloadError ?? "")
        }
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

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text(viewModel.errorMessage ?? "An error occurred")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await viewModel.fetchModelStyles()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var modelListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Downloaded Models Section
                if !downloadedItems.isEmpty {
                    sectionHeader(
                        title: "Downloaded Models",
                        count: downloadedItems.count,
                        showDeleteButton: true
                    )

                    ForEach(downloadedItems) { item in
                        ModelItemRow(
                            item: item,
                            isSelected: selectedItem?.id == item.id,
                            progress: viewModel.itemsProgress[item.id]
                        )
                        .onTap { selectItem(item) }
                        .onAction { viewModel.setItem(item) }
                    }
                }

                // Available for Download Section
                if !notDownloadedItems.isEmpty {
                    if !downloadedItems.isEmpty {
                        Divider()
                            .padding(.vertical, 4)
                    }

                    sectionHeader(
                        title: "Available for Download",
                        count: notDownloadedItems.count,
                        showDeleteButton: false
                    )

                    ForEach(notDownloadedItems) { item in
                        ModelItemRow(
                            item: item,
                            isSelected: selectedItem?.id == item.id,
                            progress: viewModel.itemsProgress[item.id]
                        )
                        .onTap { selectItem(item) }
                        .onAction { viewModel.setItem(item) }
                    }
                }
            }
            .padding()
        }
        .alert("Delete All Models", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteAllDownloadedModels()
                }
            }
        } message: {
            Text("All downloaded models will be deleted. You will need to re-download them to use again.")
        }
    }

    private func sectionHeader(title: String, count: Int, showDeleteButton: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text("\(count) model\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if showDeleteButton {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    if viewModel.isDeleting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Delete All")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    }
                }
                .disabled(viewModel.isDeleting || downloadedItems.isEmpty)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
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
        if let index = items.firstIndex(where: { $0.modelStyle.name == modelStyle.name }) {
            items[index].modelStyle = modelStyle
            if selectedItem?.modelStyle.name == modelStyle.name {
                selectedItem = items[index]
            }
        }
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

    private var onTapAction: (() -> Void)?
    private var onActionAction: (() -> Void)?

    init(item: ModelSelectView.Item, isSelected: Bool, progress: Progress?) {
        self.item = item
        self.isSelected = isSelected
        self.progress = progress
    }

    func onTap(_ action: @escaping () -> Void) -> ModelItemRow {
        var copy = self
        copy.onTapAction = action
        return copy
    }

    func onAction(_ action: @escaping () -> Void) -> ModelItemRow {
        var copy = self
        copy.onActionAction = action
        return copy
    }

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
            .onTapGesture { onTapAction?() }

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
        Button(action: { onActionAction?() }) {
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
        var id: String { modelStyle.name }
        var modelStyle: ModelStyle
        var isSelected: Bool = false
    }
}
