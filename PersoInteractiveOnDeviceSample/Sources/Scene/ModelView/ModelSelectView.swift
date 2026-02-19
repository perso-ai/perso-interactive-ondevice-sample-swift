//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import SwiftUI

import PersoInteractiveOnDeviceSDK

struct ModelSelectView: View {

    @Binding var path: [Screen]
    @StateObject private var viewModel: ModelSelectViewModel
    @State private var items: [ModelSelectView.Item] = []
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
            headerView
                .padding()

            Divider()

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
            Text("Perso Models")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Choose a model to start a session")
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

    // MARK: - Model List

    private var modelListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // First-run banner when no models are downloaded yet
                if downloadedItems.isEmpty {
                    firstRunBanner
                }

                // Ready to Use section
                if !downloadedItems.isEmpty {
                    sectionHeader(
                        title: "Ready to Use",
                        count: downloadedItems.count,
                        showDeleteButton: true
                    )

                    ForEach(downloadedItems) { item in
                        ModelCardView(
                            item: item,
                            progress: viewModel.itemsProgress[item.id]
                        )
                        .onAction { viewModel.setItem(item) }
                        .onCancel { viewModel.cancelDownload(for: item.id) }
                    }
                }

                // Divider between sections
                if !downloadedItems.isEmpty && !notDownloadedItems.isEmpty {
                    Divider()
                        .padding(.vertical, 4)
                }

                // Available for Download section
                if !notDownloadedItems.isEmpty {
                    sectionHeader(
                        title: "Available for Download",
                        count: notDownloadedItems.count,
                        showDeleteButton: false
                    )

                    ForEach(notDownloadedItems) { item in
                        ModelCardView(
                            item: item,
                            progress: viewModel.itemsProgress[item.id]
                        )
                        .onAction { viewModel.setItem(item) }
                        .onCancel { viewModel.cancelDownload(for: item.id) }
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

    // MARK: - First-Run Banner

    private var firstRunBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Get Started", systemImage: "arrow.down.circle")
                .font(.headline)
                .foregroundStyle(Color._0X644AFF)

            Text("Download a model below to begin your first interactive session.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, count: Int, showDeleteButton: Bool) -> some View {
        HStack {
            Text(title)
                .font(.headline)

            Text("(\(count))")
                .font(.headline)
                .foregroundStyle(.secondary)

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
        items = modelStyles.map { Item(modelStyle: $0) }
    }
}

// MARK: - Model Card View

private struct ModelCardView: View {
    let item: ModelSelectView.Item
    let progress: Progress?

    private var onActionHandler: (() -> Void)?
    private var onCancelHandler: (() -> Void)?

    init(item: ModelSelectView.Item, progress: Progress?) {
        self.item = item
        self.progress = progress
    }

    func onAction(_ action: @escaping () -> Void) -> ModelCardView {
        var copy = self
        copy.onActionHandler = action
        return copy
    }

    func onCancel(_ action: @escaping () -> Void) -> ModelCardView {
        var copy = self
        copy.onCancelHandler = action
        return copy
    }

    private var isDownloading: Bool {
        progress != nil
    }

    private var modelName: String {
        item.modelStyle.displayName ?? item.modelStyle.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isDownloading {
                downloadingLayout
            } else {
                standardLayout
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(modelName), \(statusText)")
    }

    // MARK: - Standard Layout (not downloading)

    private var standardLayout: some View {
        HStack(spacing: 12) {
            iconBadge

            VStack(alignment: .leading, spacing: 4) {
                Text(modelName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if item.modelStyle.displayName != nil {
                    Text(item.modelStyle.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                statusLabel
            }

            Spacer()

            ctaButton
        }
    }

    // MARK: - Downloading Layout

    private var downloadingLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                iconBadge

                VStack(alignment: .leading, spacing: 2) {
                    Text(modelName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if item.modelStyle.displayName != nil {
                        Text(item.modelStyle.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let progress {
                    Text("\(Int(progress.fractionCompleted * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Button(action: { onCancelHandler?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Cancel download")
            }

            if let progress {
                VStack(spacing: 6) {
                    ProgressView(value: progress.fractionCompleted)
                        .progressViewStyle(.linear)
                        .tint(Color._0X644AFF)

                    HStack {
                        Spacer()
                        Text("\(formatBytes(progress.completedUnitCount)) / \(formatBytes(progress.totalUnitCount))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    // MARK: - Icon Badge

    private var iconBadge: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color._0X644AFF.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "cube.box")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color._0X644AFF)
            }
            .accessibilityHidden(true)

            statusBadge
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch item.modelStyle.availability {
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.green)
                .background(Circle().fill(.background).padding(-1))
                .offset(x: 2, y: 2)

        case .unavailable(let reason):
            switch reason {
            case .notDownloaded:
                EmptyView()

            case .updateRequired:
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                    .background(Circle().fill(.background).padding(-1))
                    .offset(x: 2, y: 2)

            case .unknown:
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
                    .background(Circle().fill(.background).padding(-1))
                    .offset(x: 2, y: 2)

            @unknown default:
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
                    .background(Circle().fill(.background).padding(-1))
                    .offset(x: 2, y: 2)
            }
        }
    }

    // MARK: - Status Label

    private var statusText: String {
        switch item.modelStyle.availability {
        case .available:
            return "Ready to use"
        case .unavailable(let reason):
            switch reason {
            case .notDownloaded:
                return "Not downloaded"
            case .updateRequired:
                return "Update available"
            case .unknown:
                return "Unavailable"
            @unknown default:
                return "Unavailable"
            }
        }
    }

    private var statusColor: Color {
        switch item.modelStyle.availability {
        case .available:
            return .green
        case .unavailable(let reason):
            switch reason {
            case .notDownloaded:
                return .secondary
            case .updateRequired:
                return .orange
            case .unknown:
                return .secondary
            @unknown default:
                return .secondary
            }
        }
    }

    private var statusLabel: some View {
        Text(statusText)
            .font(.subheadline)
            .foregroundStyle(statusColor)
    }

    // MARK: - CTA Button

    @ViewBuilder
    private var ctaButton: some View {
        switch item.modelStyle.availability {
        case .available:
            Button(action: { onActionHandler?() }) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    Text("Use")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color._0X644AFF, in: Capsule())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityHint("Double tap to use this model")

        case .unavailable(let reason):
            switch reason {
            case .notDownloaded:
                Button(action: { onActionHandler?() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down")
                        Text("Get")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color._0X644AFF)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color._0X644AFF.opacity(0.15), in: Capsule())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityHint("Double tap to download this model")

            case .updateRequired:
                Button(action: { onActionHandler?() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Update")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.orange, in: Capsule())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityHint("Double tap to update this model")

            case .unknown:
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down")
                    Text("Get")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.gray.opacity(0.15), in: Capsule())
                .accessibilityHint("Model is unavailable")

            @unknown default:
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down")
                    Text("Get")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.gray.opacity(0.15), in: Capsule())
            }
        }
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesActualByteCount = false
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Item Model

extension ModelSelectView {
    struct Item: Identifiable {
        var id: String { modelStyle.name }
        var modelStyle: ModelStyle
    }
}
