//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import SwiftUI

import PersoInteractiveOnDeviceSDK

struct ModelSelectView: View {

    @Binding var path: [Screen]
    @State private var viewModel: ModelSelectViewModel
    @State private var selectedModelStyle: ModelStyle?
    @State private var configureViewModel: ConfigurationSectionViewModel?
    @State private var isModelPickerPresented = false
    @State private var pendingAutoSelectModelID: String?
    @State private var sheetFocusedModelID: String?

    init(path: Binding<[Screen]>) {
        self._path = path
        self._viewModel = State(initialValue: ModelSelectViewModel())
    }

    private var sortedItems: [Item] {
        viewModel.models.map { Item(modelStyle: $0) }.sorted { lhs, rhs in
            let lhsPriority = availabilityPriority(for: lhs.modelStyle)
            let rhsPriority = availabilityPriority(for: rhs.modelStyle)

            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }

            let lhsName = lhs.modelStyle.displayName ?? lhs.modelStyle.name
            let rhsName = rhs.modelStyle.displayName ?? rhs.modelStyle.name
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
        }
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
                configurationSetupView
            }
        }
        .task {
            await viewModel.fetchModelStyles()
        }
        .onChange(of: viewModel.models, initial: true) { _, newValue in
            syncSelectionState(with: newValue)
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
        .sheet(isPresented: $isModelPickerPresented) {
            ModelPickerSheetView(
                items: sortedItems,
                selectedModelID: selectedModelStyle?.name,
                focusedModelID: sheetFocusedModelID,
                progressByID: viewModel.itemsProgress,
                onRowTap: handleSheetRowTap(_:),
                onDownloadTap: handleDownloadTap(_:),
                onCancelDownload: handleCancelDownload(_:),
                onDeleteAll: {
                    Task {
                        await viewModel.deleteAllDownloadedModels()
                    }
                    selectedModelStyle = nil
                    configureViewModel = nil
                },
                isDeleting: viewModel.isDeleting,
                hasDownloadedModels: viewModel.models.contains {
                    if case .available = $0.availability { return true }
                    if case .unavailable(let reason) = $0.availability,
                       case .updateRequired = reason { return true }
                    return false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Top-level Subviews

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Perso Session Setup")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Select a model, then configure the session pipeline")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

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
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var configurationSetupView: some View {
        ScrollView {
            VStack(spacing: 12) {
                modelSelectionCard

                if let selectedModel = selectedModelStyle,
                   let configVM = configureViewModel {
                    ConfigurationSectionView(
                        viewModel: configVM,
                        modelStyle: selectedModel,
                        path: $path,
                        showsModelHeader: false
                    )
                    .id(selectedModel.name)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    noModelSelectedPlaceholder
                    disabledStartSessionButton
                }
            }
            .padding()
        }
    }

    // MARK: - Model Selection UI

    private var modelSelectionCard: some View {
        Button {
            sheetFocusedModelID = selectedModelStyle?.name
            isModelPickerPresented = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color._0X644AFF.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "cube.box")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color._0X644AFF)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Model")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    if let selectedModelStyle {
                        Text(selectedModelStyle.displayName ?? selectedModelStyle.name)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Text(modelStatusText(for: selectedModelStyle))
                            .font(.caption)
                            .foregroundStyle(modelStatusColor(for: selectedModelStyle))
                    } else {
                        Text("No model selected")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Tap to choose a model")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Double tap to open model picker")
    }

    private var noModelSelectedPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Select a model first", systemImage: "arrow.up.circle")
                .font(.headline)
                .foregroundStyle(Color._0X644AFF)

            Text("Choose a ready model or download one from the model picker to unlock session configuration.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var disabledStartSessionButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isModelPickerPresented = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Start Session")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.gray.opacity(0.4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(true)

            Text("Select a model to enable Start Session.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Private Methods

    private func availabilityPriority(for modelStyle: ModelStyle) -> Int {
        switch modelStyle.availability {
        case .available:
            return 0

        case .unavailable(let reason):
            switch reason {
            case .updateRequired:
                return 1
            case .notDownloaded:
                return 2
            case .unknown:
                return 3
            @unknown default:
                return 3
            }
        }
    }

    private func syncSelectionState(with modelStyles: [ModelStyle]) {
        if let selectedName = selectedModelStyle?.name {
            if let refreshedSelected = modelStyles.first(where: { $0.name == selectedName }) {
                selectedModelStyle = refreshedSelected
            } else {
                selectedModelStyle = nil
                configureViewModel = nil
            }
        }

        attemptAutoSelectAfterDownload()
    }

    private func attemptAutoSelectAfterDownload() {
        guard let pendingID = pendingAutoSelectModelID else {
            return
        }

        guard let readyModel = viewModel.models.first(where: {
            $0.name == pendingID && $0.availability == .available
        }) else {
            return
        }

        pendingAutoSelectModelID = nil
        selectModel(readyModel, closePicker: true)
    }

    private func selectModel(_ modelStyle: ModelStyle, closePicker: Bool = false) {
        if selectedModelStyle?.name == modelStyle.name {
            selectedModelStyle = modelStyle
            if closePicker {
                isModelPickerPresented = false
            }
            return
        }

        let snapshot = configureViewModel?.makeSelectionSnapshot()
        selectedModelStyle = modelStyle

        let vm = ConfigurationSectionViewModel(modelStyle: modelStyle)
        configureViewModel = vm

        Task {
            await vm.fetchAvailableFeatures()

            guard configureViewModel === vm else {
                return
            }

            if let snapshot {
                vm.restoreSelection(from: snapshot)
            }
        }

        if closePicker {
            isModelPickerPresented = false
        }
    }

    private func handleSheetRowTap(_ item: Item) {
        switch item.modelStyle.availability {
        case .available:
            sheetFocusedModelID = item.id
            selectModel(item.modelStyle, closePicker: true)

        case .unavailable:
            sheetFocusedModelID = item.id
        }
    }

    private func handleDownloadTap(_ item: Item) {
        pendingAutoSelectModelID = item.id
        sheetFocusedModelID = item.id
        viewModel.setItem(item)
    }

    private func handleCancelDownload(_ item: Item) {
        if pendingAutoSelectModelID == item.id {
            pendingAutoSelectModelID = nil
        }
        viewModel.cancelDownload(for: item.id)
    }

    private func modelStatusText(for modelStyle: ModelStyle) -> String {
        switch modelStyle.availability {
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

    private func modelStatusColor(for modelStyle: ModelStyle) -> Color {
        switch modelStyle.availability {
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
}

private struct ModelPickerSheetView: View {

    @Environment(\.dismiss) private var dismiss

    let items: [ModelSelectView.Item]
    let selectedModelID: String?
    let focusedModelID: String?
    let progressByID: [String: Progress]
    let onRowTap: (ModelSelectView.Item) -> Void
    let onDownloadTap: (ModelSelectView.Item) -> Void
    let onCancelDownload: (ModelSelectView.Item) -> Void
    let onDeleteAll: () -> Void
    let isDeleting: Bool
    let hasDownloadedModels: Bool

    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            pickerScrollContent
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            dismiss()
                        }
                        .keyboardShortcut(.cancelAction)
                    }

                    ToolbarItem(placement: .automatic) {
                        if isDeleting {
                            ProgressView()
                        } else {
                            Button {
                                showDeleteAlert = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .disabled(!hasDownloadedModels || isDeleting)
                        }
                    }
                }
                .alert("Delete All Models", isPresented: $showDeleteAlert) {
                    Button("Delete All", role: .destructive) {
                        onDeleteAll()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("All downloaded model data will be removed. You can re-download them later.")
                }
        }
    }

    @ViewBuilder
    private var pickerScrollContent: some View {
        #if os(macOS)
        basePickerScrollContent
            .navigationTitle("Select Model")
        #else
        basePickerScrollContent
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var basePickerScrollContent: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if items.isEmpty {
                    emptyStateView
                } else {
                    ForEach(items) { item in
                        ModelPickerRow(
                            item: item,
                            isSelected: item.id == selectedModelID,
                            isFocused: item.id == focusedModelID,
                            progress: progressByID[item.id],
                            onTap: { onRowTap(item) },
                            onDownloadTap: { onDownloadTap(item) },
                            onCancelTap: { onCancelDownload(item) },
                            isDeleting: isDeleting
                        )
                    }
                }
            }
            .padding()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("No models available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

private struct ModelPickerRow: View {

    let item: ModelSelectView.Item
    let isSelected: Bool
    let isFocused: Bool
    let progress: Progress?
    let onTap: () -> Void
    let onDownloadTap: () -> Void
    let onCancelTap: () -> Void
    let isDeleting: Bool

    private var isDownloading: Bool {
        progress != nil && item.modelStyle.availability != .available
    }

    private var isFinalizing: Bool {
        isDownloading && (progress?.fractionCompleted ?? 0) >= 1.0
    }

    private var modelName: String {
        item.modelStyle.displayName ?? item.modelStyle.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color._0X644AFF.opacity(0.15))
                            .frame(width: 42, height: 42)

                        Image(systemName: "cube.box")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color._0X644AFF)
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                            .background(Circle().fill(.background).padding(-1))
                            .offset(x: 2, y: 2)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(modelName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if item.modelStyle.displayName != nil {
                        Text(item.modelStyle.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }

                Spacer()

                actionArea
            }

            if let progress {
                VStack(spacing: 6) {
                    ProgressView(value: progress.fractionCompleted)
                        .progressViewStyle(.linear)
                        .tint(Color._0X644AFF)

                    HStack {
                        Spacer()
                        Text("\(Int(progress.fractionCompleted * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: borderLineWidth)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(modelName), \(statusText)")
    }

    private var borderColor: Color {
        if isSelected {
            return .green.opacity(0.7)
        }
        if isFocused {
            return Color._0X644AFF.opacity(0.7)
        }
        return .clear
    }

    private var borderLineWidth: CGFloat {
        if isSelected || isFocused {
            return 1
        }
        return 0
    }

    private var statusText: String {
        if isFinalizing {
            return "Finalizing..."
        }

        if isDownloading {
            return "Downloading"
        }

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
        if isFinalizing {
            return .secondary
        }

        if isDownloading {
            return Color._0X644AFF
        }

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

    @ViewBuilder
    private var actionArea: some View {
        if isDownloading {
            Button(action: onCancelTap) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel download")
        } else {
            switch item.modelStyle.availability {
            case .available:
                if isSelected {
                    Text("Selected")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.green.opacity(0.12), in: Capsule())
                } else {
                    Text("Tap to select")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            case .unavailable(let reason):
                switch reason {
                case .notDownloaded:
                    downloadButton(title: "Get", icon: "arrow.down", tint: Color._0X644AFF)

                case .updateRequired:
                    downloadButton(title: "Update", icon: "arrow.clockwise", tint: .orange)

                case .unknown:
                    Text("Unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                @unknown default:
                    Text("Unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func downloadButton(title: String, icon: String, tint: Color) -> some View {
        Button(action: onDownloadTap) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(tint, in: Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .opacity(isDeleting ? 0.5 : 1.0)
        .disabled(isDeleting)
    }
}

extension ModelSelectView {
    struct Item: Identifiable {
        var id: String { modelStyle.name }
        var modelStyle: ModelStyle
    }
}
