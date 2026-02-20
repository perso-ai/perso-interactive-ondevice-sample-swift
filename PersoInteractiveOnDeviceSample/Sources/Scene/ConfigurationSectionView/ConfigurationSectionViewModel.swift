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

    var selectedSTTIndex: Int = 0
    var selectedLLMIndex: Int = 0
    var selectedPromptIndex: Int = 0
    var selectedDocumentIndex: Int?
    var selectedTTSIndex: Int = 0
    var selectedMCPServerIndices: Set<Int> = []

    init(modelStyle: ModelStyle) {
        self.modelStyle = modelStyle
    }

    // MARK: - Public Methods

    func fetchAvailableFeatures() async {
        isLoading = true
        errorMessage = nil

        do {
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

            selectedSTTIndex = 0
            selectedLLMIndex = 0
            selectedPromptIndex = 0
            selectedTTSIndex = 0
            selectedDocumentIndex = availableDocuments.indices.first
            selectedMCPServerIndices = Set(availableMCPServers.indices)

            isLoading = false
        } catch {
            errorMessage = "Failed to load features: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func makeSelectionSnapshot() -> SelectionSnapshot? {
        guard availableSTTTypes.indices.contains(selectedSTTIndex),
              availableLLMTypes.indices.contains(selectedLLMIndex),
              availablePrompts.indices.contains(selectedPromptIndex),
              availableTTSTypes.indices.contains(selectedTTSIndex)
        else { return nil }

        let documentTitle: String? = selectedDocumentIndex.flatMap { index in
            availableDocuments.indices.contains(index) ? availableDocuments[index].title : nil
        }

        let mcpServerNames = Set(selectedMCPServerIndices.compactMap { index in
            availableMCPServers.indices.contains(index) ? availableMCPServers[index].name : nil
        })

        return SelectionSnapshot(
            sttName: availableSTTTypes[selectedSTTIndex].name,
            llmName: availableLLMTypes[selectedLLMIndex].name,
            promptName: availablePrompts[selectedPromptIndex].name,
            documentTitle: documentTitle,
            ttsName: availableTTSTypes[selectedTTSIndex].name,
            mcpServerNames: mcpServerNames
        )
    }

    func restoreSelection(from snapshot: SelectionSnapshot) {
        if let sttIndex = availableSTTTypes.firstIndex(where: { $0.name == snapshot.sttName }) {
            selectedSTTIndex = sttIndex
        }

        if let llmIndex = availableLLMTypes.firstIndex(where: { $0.name == snapshot.llmName }) {
            selectedLLMIndex = llmIndex
        }

        if let promptIndex = availablePrompts.firstIndex(where: { $0.name == snapshot.promptName }) {
            selectedPromptIndex = promptIndex
        }

        if let documentTitle = snapshot.documentTitle {
            selectedDocumentIndex = availableDocuments.firstIndex(where: { $0.title == documentTitle })
        } else {
            selectedDocumentIndex = nil
        }

        if let ttsIndex = availableTTSTypes.firstIndex(where: { $0.name == snapshot.ttsName }) {
            selectedTTSIndex = ttsIndex
        }

        let restoredMCPIndices = Set(availableMCPServers.indices.filter { index in
            snapshot.mcpServerNames.contains(availableMCPServers[index].name)
        })

        if !restoredMCPIndices.isEmpty {
            selectedMCPServerIndices = restoredMCPIndices
        }
    }

    func buildConfiguration() -> SessionConfiguration? {
        guard availableSTTTypes.indices.contains(selectedSTTIndex),
              availableLLMTypes.indices.contains(selectedLLMIndex),
              availablePrompts.indices.contains(selectedPromptIndex),
              availableTTSTypes.indices.contains(selectedTTSIndex)
        else { return nil }

        let selectedMCPs = selectedMCPServerIndices.sorted().compactMap { index in
            availableMCPServers.indices.contains(index) ? availableMCPServers[index] : nil
        }

        return SessionConfiguration(
            modelStyle: modelStyle,
            sttType: availableSTTTypes[selectedSTTIndex],
            llmType: availableLLMTypes[selectedLLMIndex],
            prompt: availablePrompts[selectedPromptIndex],
            document: selectedDocumentIndex.flatMap { availableDocuments.indices.contains($0) ? availableDocuments[$0] : nil },
            ttsType: availableTTSTypes[selectedTTSIndex],
            mcpServers: selectedMCPs
        )
    }

    var canStartSession: Bool {
        !availableSTTTypes.isEmpty &&
        !availableLLMTypes.isEmpty &&
        !availablePrompts.isEmpty &&
        !availableTTSTypes.isEmpty
    }
}
