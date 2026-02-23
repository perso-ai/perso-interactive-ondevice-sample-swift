//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import SwiftUI

import PersoInteractiveOnDeviceSDK

// MARK: - Configuration Section View

/// An inline configuration section that appears within ModelSelectView after a model is selected.
/// Renders model identity, all configuration cards, and a Start Session button.
struct ConfigurationSectionView: View {

    @Bindable var viewModel: ConfigurationSectionViewModel
    let modelStyle: ModelStyle
    @Binding var path: [Screen]
    var showsModelHeader: Bool = true

    var body: some View {
        if let errorMessage = viewModel.errorMessage {
            configurationErrorView(errorMessage)
        } else if viewModel.isLoading {
            configurationLoadingView
        } else {
            configurationContent
        }
    }

    // MARK: - Loading

    private var configurationLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

            Text("Loading available features...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Error

    private func configurationErrorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await viewModel.fetchAvailableFeatures()
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Content

    private var configurationContent: some View {
        VStack(spacing: 12) {
            if showsModelHeader {
                headerView
            } else {
                sectionTitle
            }

            // Pipeline cards
            sttCard
            llmCard
            promptCard
            documentCard
            ttsCard
            mcpServersCard

            startSessionButton
                .padding(.top, 4)
        }
        .onChange(of: viewModel.selectedPrompt) { _, _ in
            if viewModel.selectedPromptRequiresDocument && viewModel.selectedDocument == nil {
                viewModel.selectedDocument = viewModel.availableDocuments.first
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 16) {
            // Model identity badge
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color._0X644AFF, Color._0X644AFF.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(modelStyle.displayName ?? modelStyle.name)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(modelStyle.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Readiness indicator
                if viewModel.canStartSession {
                    Label("Ready", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.green.opacity(0.12), in: Capsule())
                }
            }
            .padding()
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Section title
            HStack {
                sectionTitle
                Spacer()
            }
        }
    }

    private var sectionTitle: some View {
        Text("Configure Session")
            .font(.headline)
            .foregroundStyle(.secondary)
    }

    // MARK: - STT Card

    @ViewBuilder
    private var sttCard: some View {
        if !viewModel.availableSTTTypes.isEmpty {
            ConfigurationCard(
                icon: "waveform",
                iconColor: .blue,
                title: "Speech to Text",
                subtitle: viewModel.selectedSTT?.name ?? ""
            ) {
                Picker("STT Model", selection: $viewModel.selectedSTT) {
                    ForEach(viewModel.availableSTTTypes, id: \.self) { sttType in
                        Text(sttType.name)
                            .tag(sttType as STTType?)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)
            }
        }
    }

    // MARK: - LLM Card

    @ViewBuilder
    private var llmCard: some View {
        if !viewModel.availableLLMTypes.isEmpty {
            ConfigurationCard(
                icon: "brain",
                iconColor: Color._0X644AFF,
                title: "Language Model",
                subtitle: viewModel.selectedLLM?.name ?? ""
            ) {
                Picker("LLM Model", selection: $viewModel.selectedLLM) {
                    ForEach(viewModel.availableLLMTypes, id: \.self) { llmType in
                        Text(llmType.name)
                            .tag(llmType as LLMType?)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)
            }
        }
    }

    // MARK: - Prompt Card

    @ViewBuilder
    private var promptCard: some View {
        if !viewModel.availablePrompts.isEmpty {
            ConfigurationCard(
                icon: "text.bubble",
                iconColor: .orange,
                title: "Prompt",
                subtitle: viewModel.selectedPrompt?.name ?? ""
            ) {
                Picker("Prompt", selection: $viewModel.selectedPrompt) {
                    ForEach(viewModel.availablePrompts, id: \.self) { prompt in
                        Text(prompt.name)
                            .tag(prompt as Prompt?)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)
            }
        }
    }

    // MARK: - Document Card

    @ViewBuilder
    private var documentCard: some View {
        if !viewModel.availableDocuments.isEmpty {
            ConfigurationCard(
                icon: "doc.text",
                iconColor: .cyan,
                title: "Document",
                subtitle: viewModel.selectedDocument?.title ?? "None"
            ) {
                if viewModel.selectedPromptRequiresDocument {
                    Text("Required")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.orange, in: Capsule())
                        .padding(.bottom, 4)
                }

                Picker("Document", selection: $viewModel.selectedDocument) {
                    if !viewModel.selectedPromptRequiresDocument {
                        Text("None").tag(nil as Document?)
                    }
                    ForEach(viewModel.availableDocuments, id: \.self) { document in
                        Text(document.title)
                            .tag(document as Document?)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)

                if viewModel.isDocumentSelectionMissing {
                    Label("Selected prompt requires a document", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 4)
                }
            }
        } else if viewModel.selectedPromptRequiresDocument {
            ConfigurationCard(
                icon: "doc.text",
                iconColor: .cyan,
                title: "Document",
                subtitle: "No documents available"
            ) {
                if viewModel.selectedPromptRequiresDocument {
                    Text("Required")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.orange, in: Capsule())
                        .padding(.bottom, 4)
                }

                Label("Selected prompt requires a document, but none are available",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - TTS Card

    @ViewBuilder
    private var ttsCard: some View {
        if !viewModel.availableTTSTypes.isEmpty {
            ConfigurationCard(
                icon: "speaker.wave.3",
                iconColor: .green,
                title: "Text to Speech",
                subtitle: ttsSubtitle
            ) {
                Picker("TTS Model", selection: $viewModel.selectedTTS) {
                    ForEach(viewModel.availableTTSTypes, id: \.self) { ttsType in
                        Text(ttsType.name)
                            .tag(ttsType as TTSType?)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)

                if let voice = viewModel.selectedTTS?.voice {
                    Label(voice, systemImage: "person.wave.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }

    private var ttsSubtitle: String {
        guard let tts = viewModel.selectedTTS else { return "" }
        if let voice = tts.voice {
            return "\(tts.name) -- \(voice)"
        }
        return tts.name
    }

    // MARK: - MCP Servers Card

    @ViewBuilder
    private var mcpServersCard: some View {
        if !viewModel.availableMCPServers.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // Card header
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.indigo.opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: "server.rack")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.indigo)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("MCP Servers")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        let selectedCount = viewModel.selectedMCPServers.count
                        let totalCount = viewModel.availableMCPServers.count
                        Text("\(selectedCount) of \(totalCount) selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("External tool servers for extended capabilities")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                Divider()
                    .padding(.leading, 64)

                // Server toggles
                VStack(spacing: 0) {
                    ForEach(viewModel.availableMCPServers, id: \.self) { server in
                        Toggle(isOn: Binding(
                            get: { viewModel.selectedMCPServers.contains(server) },
                            set: { isOn in
                                if isOn {
                                    viewModel.selectedMCPServers.insert(server)
                                } else {
                                    viewModel.selectedMCPServers.remove(server)
                                }
                            }
                        )) {
                            HStack(spacing: 10) {
                                Image(systemName: viewModel.selectedMCPServers.contains(server)
                                       ? "bolt.fill"
                                       : "bolt.slash")
                                    .font(.caption)
                                    .foregroundStyle(viewModel.selectedMCPServers.contains(server)
                                                     ? .indigo
                                                     : .secondary)
                                    .frame(width: 20)

                                Text(server.name)
                                    .font(.subheadline)
                            }
                        }
                        .tint(.indigo)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        if server != viewModel.availableMCPServers.last {
                            Divider()
                                .padding(.leading, 64)
                        }
                    }
                }
                .padding(.bottom, 4)
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Start Session Button

    private var startSessionButton: some View {
        Button {
            guard let configuration = viewModel.buildConfiguration() else { return }
            path.append(.main(configuration))
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("Start Session")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if viewModel.canStartSession {
                        LinearGradient(
                            colors: [Color._0X644AFF, Color._0X644AFF.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color.gray.opacity(0.4)
                    }
                }
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(
                color: viewModel.canStartSession ? Color._0X644AFF.opacity(0.35) : .clear,
                radius: 12,
                y: 6
            )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!viewModel.canStartSession)
    }

    // MARK: - Helpers

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.regularMaterial)
    }
}

// MARK: - Configuration Card Component

/// A reusable card component for each configuration category.
/// Displays an icon, title, current selection summary, and a picker area.
struct ConfigurationCard<Content: View>: View {

    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    init(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 12) {
                // Category icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

                // Title and current value
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
                .padding(.leading, 64)

            VStack(alignment: .leading, spacing: 4) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.regularMaterial)
    }
}
