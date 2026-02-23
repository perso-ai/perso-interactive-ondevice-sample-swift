//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import Foundation
import Observation

import PersoInteractiveOnDeviceSDK

@MainActor
@Observable final class ConfigurationSectionViewModel {

    struct SelectionSnapshot {
        let sttName: String
        let llmName: String
        let promptName: String
        let documentTitle: String?
        let ttsName: String
        let mcpServerNames: Set<String>
    }

    let modelStyle: ModelStyle

    var isLoading = true
    var errorMessage: String?

    var availableSTTTypes: [STTType] = []
    var availableLLMTypes: [LLMType] = []
    var availablePrompts: [Prompt] = []
    var availableDocuments: [Document] = []
    var availableTTSTypes: [TTSType] = []
    var availableMCPServers: [MCPServer] = []

    var selectedSTT: STTType?
    var selectedLLM: LLMType?
    var selectedPrompt: Prompt?
    var selectedDocument: Document?
    var selectedTTS: TTSType?
    var selectedMCPServers: Set<MCPServer> = []

    init(modelStyle: ModelStyle) {
        self.modelStyle = modelStyle
    }

    // MARK: - Public Methods

    func fetchAvailableFeatures() async {
        isLoading = true
        errorMessage = nil

        do {
            defer { isLoading = false }

            async let sttTypes = PersoInteractive.fetchAvailableSTTModels()
            async let llmTypes = PersoInteractive.fetchAvailableLLMModels()
            async let prompts = PersoInteractive.fetchAvailablePrompts()
            async let documents = PersoInteractive.fetchAvailableDocuments()
            async let ttsTypes = PersoInteractive.fetchAvailableTTSModels()
            async let mcpServers = PersoInteractive.fetchAvailableMCPServers()

            (availableSTTTypes, availableLLMTypes, availablePrompts, availableDocuments, availableTTSTypes, availableMCPServers) = try await (
                sttTypes, llmTypes, prompts, documents, ttsTypes, mcpServers
            )

            availableSTTTypes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            availableLLMTypes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            availablePrompts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            availableDocuments.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            availableTTSTypes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            availableMCPServers.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            selectedSTT = availableSTTTypes.first
            selectedLLM = availableLLMTypes.first
            selectedPrompt = availablePrompts.first
            selectedDocument = availableDocuments.first
            selectedTTS = availableTTSTypes.first
            selectedMCPServers = Set(availableMCPServers)
        } catch {
            errorMessage = "Failed to load features: \(error.localizedDescription)"
        }
    }

    func makeSelectionSnapshot() -> SelectionSnapshot? {
        guard let selectedSTT,
              let selectedLLM,
              let selectedPrompt,
              let selectedTTS
        else { return nil }

        return SelectionSnapshot(
            sttName: selectedSTT.name,
            llmName: selectedLLM.name,
            promptName: selectedPrompt.name,
            documentTitle: selectedDocument?.title,
            ttsName: selectedTTS.name,
            mcpServerNames: Set(selectedMCPServers.map(\.name))
        )
    }

    func restoreSelection(from snapshot: SelectionSnapshot) {
        if let stt = availableSTTTypes.first(where: { $0.name == snapshot.sttName }) {
            selectedSTT = stt
        }
        if let llm = availableLLMTypes.first(where: { $0.name == snapshot.llmName }) {
            selectedLLM = llm
        }
        if let prompt = availablePrompts.first(where: { $0.name == snapshot.promptName }) {
            selectedPrompt = prompt
        }
        if let documentTitle = snapshot.documentTitle {
            selectedDocument = availableDocuments.first(where: { $0.title == documentTitle })
        } else {
            selectedDocument = nil
        }
        if let tts = availableTTSTypes.first(where: { $0.name == snapshot.ttsName }) {
            selectedTTS = tts
        }
        let restoredMCPs = availableMCPServers.filter { snapshot.mcpServerNames.contains($0.name) }
        if !restoredMCPs.isEmpty {
            selectedMCPServers = Set(restoredMCPs)
        }
    }

    func buildConfiguration() -> SessionConfiguration? {
        guard let selectedSTT,
              let selectedLLM,
              let selectedPrompt,
              let selectedTTS
        else { return nil }

        return SessionConfiguration(
            modelStyle: modelStyle,
            sttType: selectedSTT,
            llmType: selectedLLM,
            prompt: selectedPrompt,
            document: selectedDocument,
            ttsType: selectedTTS,
            mcpServers: Array(selectedMCPServers)
        )
    }

    var selectedPromptRequiresDocument: Bool {
        selectedPrompt?.requireDocument == true
    }

    var isDocumentSelectionMissing: Bool {
        selectedPromptRequiresDocument && selectedDocument == nil
    }

    var canStartSession: Bool {
        selectedSTT != nil &&
        selectedLLM != nil &&
        selectedPrompt != nil &&
        selectedTTS != nil &&
        !isDocumentSelectionMissing
    }
}
