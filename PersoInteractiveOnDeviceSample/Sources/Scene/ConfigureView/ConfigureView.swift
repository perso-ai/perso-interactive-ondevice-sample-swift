//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import SwiftUI

import PersoInteractiveOnDeviceSDK

// MARK: - Configuration Section View

/// An inline configuration section that appears within ModelSelectView after a model is selected.
/// Renders model identity, all configuration cards, and a Start Session button.
struct ConfigurationSectionView: View {

    @ObservedObject var viewModel: ConfigureViewModel
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
                subtitle: viewModel.availableSTTTypes[viewModel.selectedSTTIndex].name,
                description: "Converts voice input to text"
            ) {
                Picker("STT Model", selection: $viewModel.selectedSTTIndex) {
                    ForEach(viewModel.availableSTTTypes.indices, id: \.self) { index in
                        Text(viewModel.availableSTTTypes[index].name)
                            .tag(index)
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
                subtitle: viewModel.availableLLMTypes[viewModel.selectedLLMIndex].name,
                description: "AI language model for conversation"
            ) {
                Picker("LLM Model", selection: $viewModel.selectedLLMIndex) {
                    ForEach(viewModel.availableLLMTypes.indices, id: \.self) { index in
                        Text(viewModel.availableLLMTypes[index].name)
                            .tag(index)
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
                subtitle: viewModel.availablePrompts[viewModel.selectedPromptIndex].name,
                description: "System prompt defining AI personality"
            ) {
                Picker("Prompt", selection: $viewModel.selectedPromptIndex) {
                    ForEach(viewModel.availablePrompts.indices, id: \.self) { index in
                        Text(viewModel.availablePrompts[index].name)
                            .tag(index)
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
                subtitle: viewModel.selectedDocumentIndex.flatMap {
                    viewModel.availableDocuments.indices.contains($0)
                        ? viewModel.availableDocuments[$0].title
                        : nil
                } ?? "None",
                description: "RAG document for contextual knowledge"
            ) {
                Picker("Document", selection: $viewModel.selectedDocumentIndex) {
                    Text("None").tag(nil as Int?)
                    ForEach(viewModel.availableDocuments.indices, id: \.self) { index in
                        Text(viewModel.availableDocuments[index].title)
                            .tag(index as Int?)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)
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
                subtitle: ttsSubtitle,
                description: "Converts AI response to speech"
            ) {
                Picker("TTS Model", selection: $viewModel.selectedTTSIndex) {
                    ForEach(viewModel.availableTTSTypes.indices, id: \.self) { index in
                        Text(viewModel.availableTTSTypes[index].name)
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)

                if let voice = viewModel.availableTTSTypes[viewModel.selectedTTSIndex].voice {
                    Label(voice, systemImage: "person.wave.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }

    private var ttsSubtitle: String {
        let tts = viewModel.availableTTSTypes[viewModel.selectedTTSIndex]
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

                        let selectedCount = viewModel.selectedMCPServerIndices.count
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
                    ForEach(viewModel.availableMCPServers.indices, id: \.self) { index in
                        Toggle(isOn: Binding(
                            get: { viewModel.selectedMCPServerIndices.contains(index) },
                            set: { isOn in
                                if isOn {
                                    viewModel.selectedMCPServerIndices.insert(index)
                                } else {
                                    viewModel.selectedMCPServerIndices.remove(index)
                                }
                            }
                        )) {
                            HStack(spacing: 10) {
                                Image(systemName: viewModel.selectedMCPServerIndices.contains(index)
                                       ? "bolt.fill"
                                       : "bolt.slash")
                                    .font(.caption)
                                    .foregroundStyle(viewModel.selectedMCPServerIndices.contains(index)
                                                     ? .indigo
                                                     : .secondary)
                                    .frame(width: 20)

                                Text(viewModel.availableMCPServers[index].name)
                                    .font(.subheadline)
                            }
                        }
                        .tint(.indigo)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        if index < viewModel.availableMCPServers.count - 1 {
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
/// Displays an icon, title, current selection summary, and an expandable picker area.
struct ConfigurationCard<Content: View>: View {

    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let description: String?
    @ViewBuilder let content: () -> Content

    @State private var isExpanded = true

    init(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        description: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tappable header row
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
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

                        if !isExpanded, let description {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Expand chevron
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expandable picker content
            if isExpanded {
                Divider()
                    .padding(.leading, 64)

                VStack(alignment: .leading, spacing: 4) {
                    content()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.regularMaterial)
    }
}
