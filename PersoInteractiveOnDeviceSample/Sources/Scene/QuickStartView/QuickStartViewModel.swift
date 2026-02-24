//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import Foundation
import Observation
import PersoInteractiveOnDeviceSDK

@MainActor
@Observable final class QuickStartViewModel {

    // MARK: - Quick Start Default Configuration
    // Modify these defaults to match your preferred configuration.
    // The app will auto-select items matching these names from SDK results.
    // Falls back to the first available item if no match is found.

    private enum Defaults {
        static let modelStyle: String? = nil      // nil selects the first available model
        static let sttType: String? = nil         // e.g. "whisper"
        static let llmType: String? = nil         // e.g. "llama"
        static let prompt: String? = nil
        static let document: String? = nil        // nil proceeds without a document
        static let ttsType: String? = nil
        static let selectAllMCPServers = true     // true selects all available MCP servers
    }

    enum State {
        case loading(String)                    // step message
        case downloading(ModelStyle, Double)    // model + progress 0.0~1.0
        case error(String)                      // error message
    }

    var state: State = .loading("Preparing...")

    func configure() async -> SessionConfiguration? {
        // Step 1: Fetch model styles
        state = .loading("Checking models...")

        let modelStyles: [ModelStyle]
        do {
            modelStyles = try await PersoInteractive.fetchAvailableModelStyles()
        } catch {
            state = .error("Failed to load models: \(error.localizedDescription)")
            return nil
        }

        guard !modelStyles.isEmpty else {
            state = .error("No models available")
            return nil
        }

        // Find matching or first available model
        let selectedModel: ModelStyle

        if let name = Defaults.modelStyle {
            // Specific model requested
            guard let match = modelStyles.first(where: { $0.name == name }) else {
                state = .error("Specified model '\(name)' not found.")
                return nil
            }
            if match.availability == .available {
                selectedModel = match
            } else {
                // Specified model not yet downloaded — auto-download
                guard let downloaded = await downloadModel(match) else { return nil }
                selectedModel = downloaded
            }
        } else {
            // No model specified: use first available, or download the first one
            if let available = modelStyles.first(where: { $0.availability == .available }) {
                selectedModel = available
            } else {
                guard let downloaded = await downloadModel(modelStyles[0]) else { return nil }
                selectedModel = downloaded
            }
        }

        // Step 2: Fetch all configuration options in parallel
        state = .loading("Loading configuration...")

        do {
            async let sttTypes = PersoInteractive.fetchAvailableSTTModels()
            async let llmTypes = PersoInteractive.fetchAvailableLLMModels()
            async let prompts = PersoInteractive.fetchAvailablePrompts()
            async let documents = PersoInteractive.fetchAvailableDocuments()
            async let ttsTypes = PersoInteractive.fetchAvailableTTSModels()
            async let mcpServers = PersoInteractive.fetchAvailableMCPServers()

            let (fetchedSTT, fetchedLLM, fetchedPrompts, fetchedDocuments, fetchedTTS, fetchedMCP) = try await (
                sttTypes, llmTypes, prompts, documents, ttsTypes, mcpServers
            )

            // Match by name or fallback to first
            guard let selectedSTT = match(name: Defaults.sttType, in: fetchedSTT, by: \.name) else {
                state = .error("No STT models available")
                return nil
            }
            guard let selectedLLM = match(name: Defaults.llmType, in: fetchedLLM, by: \.name) else {
                state = .error("No LLM models available")
                return nil
            }
            guard let selectedPrompt = match(name: Defaults.prompt, in: fetchedPrompts, by: \.name) else {
                state = .error("No prompts available")
                return nil
            }
            guard let selectedTTS = match(name: Defaults.ttsType, in: fetchedTTS, by: \.name) else {
                state = .error("No TTS models available")
                return nil
            }

            // Document: match by title, or nil if Defaults.document is nil
            let selectedDocument: Document?
            if let docName = Defaults.document {
                selectedDocument = fetchedDocuments.first(where: { $0.title == docName }) ?? fetchedDocuments.first
            } else {
                selectedDocument = nil
            }

            // MCP Servers
            let selectedMCPServers: [MCPServer]
            if Defaults.selectAllMCPServers {
                selectedMCPServers = fetchedMCP
            } else {
                selectedMCPServers = []
            }

            state = .loading("Preparing session...")

            return SessionConfiguration(
                modelStyle: selectedModel,
                sttType: selectedSTT,
                llmType: selectedLLM,
                prompt: selectedPrompt,
                document: selectedDocument,
                ttsType: selectedTTS,
                mcpServers: selectedMCPServers
            )
        } catch {
            state = .error("Failed to load configuration: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private

    private func downloadModel(_ model: ModelStyle) async -> ModelStyle? {
        state = .downloading(model, 0.0)

        do {
            let stream = PersoInteractive.loadModelStyle(with: model)

            for try await progress in stream {
                try Task.checkCancellation()
                switch progress {
                case .progressing(let progressObj):
                    state = .downloading(model, progressObj.fractionCompleted)
                    if progressObj.fractionCompleted >= 1.0 {
                        if let polled = await pollUntilAvailable(modelName: model.name) {
                            return polled
                        }
                    }
                case .finished(let updatedModel):
                    return updatedModel
                }
            }

            // Stream ended without .finished — try polling
            return await pollUntilAvailable(modelName: model.name)

        } catch is CancellationError {
            return nil
        } catch {
            state = .error("Download failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func pollUntilAvailable(modelName: String) async -> ModelStyle? {
        for _ in 0..<6 {
            guard !Task.isCancelled else { return nil }
            if let style = await fetchModelStyle(named: modelName),
               style.availability == .available {
                return style
            }
            try? await Task.sleep(for: .milliseconds(700))
        }
        state = .error("Download completed but model is not yet available.")
        return nil
    }

    private func fetchModelStyle(named modelName: String) async -> ModelStyle? {
        do {
            let styles = try await PersoInteractive.fetchAvailableModelStyles()
            return styles.first(where: { $0.name == modelName })
        } catch {
            return nil
        }
    }

    private func match<T>(name: String?, in items: [T], by keyPath: KeyPath<T, String>) -> T? {
        if let name, let found = items.first(where: { $0[keyPath: keyPath] == name }) {
            return found
        }
        return items.first
    }
}
