//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import Combine
import Foundation

import PersoInteractiveOnDeviceSDK

/// ViewModel for managing model selection and download state
@MainActor
final class ModelSelectViewModel: ObservableObject {

    // MARK: - Published Properties

    /// List of available model styles
    @Published var models: [ModelStyle] = []

    /// Download/Update progress for each model item
    @Published var itemsProgress: [String: Progress] = [:]

    /// Loading state
    @Published var isLoading: Bool = false

    /// Error message if fetch fails
    @Published var errorMessage: String?

    /// Error message if download fails
    @Published var downloadError: String?

    /// Deleting state
    @Published var isDeleting: Bool = false

    private var downloadTasks: [String: Task<Void, Never>] = [:]

    // MARK: - Subjects

    /// Signals navigation to main screen when model is ready
    let moveToMainTabScreen = PassthroughSubject<ModelStyle, Never>()

    // MARK: - Initialization

    init() { }

    // MARK: - Public Methods

    /// Fetches available model styles from the SDK
    func fetchModelStyles() async {
        isLoading = true
        errorMessage = nil

        do {
            let modelStyles = try await PersoInteractive.fetchAvailableModelStyles()

            guard !modelStyles.isEmpty else {
                errorMessage = "No models available"
                isLoading = false
                return
            }

            self.models = modelStyles
            isLoading = false

        } catch {
            errorMessage = "Failed to load models: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// Handles model selection - either navigates to main screen or starts download
    func setItem(_ item: ModelSelectView.Item) {
        let modelStyle = item.modelStyle

        switch modelStyle.availability {
        case .available:
            moveToMainTabScreen.send(modelStyle)

        case .unavailable(_):
            downloadTasks[item.id]?.cancel()
            downloadTasks[item.id] = Task {
                await loadModelResources(modelStyle: modelStyle, for: item.id)
            }
        }
    }

    /// Refreshes the availability status of all models
    func refreshModelStatus() async {
        await fetchModelStyles()
    }

    /// Deletes all downloaded model resources and refreshes the list
    func deleteAllDownloadedModels() async {
        isDeleting = true
        PersoInteractive.cleanModelResources()
        await fetchModelStyles()
        isDeleting = false
    }

    /// Cancels an in-progress download for the specified model
    func cancelDownload(for itemID: String) {
        downloadTasks[itemID]?.cancel()
        downloadTasks[itemID] = nil
        itemsProgress[itemID] = nil
    }

    // MARK: - Private Methods

    /// Downloads or updates model resources and tracks progress
    private func loadModelResources(modelStyle: ModelStyle, for itemID: String) async {
        do {
            let stream = PersoInteractive.loadModelStyle(with: modelStyle)

            for try await progress in stream {
                try Task.checkCancellation()
                switch progress {
                case .progressing(let progressObj):
                    self.itemsProgress[itemID] = progressObj
                case .finished(let updatedModelStyle):
                    self.itemsProgress[itemID] = nil
                    self.downloadTasks[itemID] = nil
                    updateModelStyleStatus(from: updatedModelStyle)
                }
            }

            // Stream이 .finished 없이 정상 종료된 경우 cleanup
            if self.itemsProgress[itemID] != nil {
                self.itemsProgress[itemID] = nil
                self.downloadTasks[itemID] = nil
                await fetchModelStyles()
            }

        } catch is CancellationError {
            self.itemsProgress[itemID] = nil
            self.downloadTasks[itemID] = nil
        } catch {
            self.itemsProgress[itemID] = nil
            self.downloadTasks[itemID] = nil
            downloadError = "Download failed: \(error.localizedDescription)"
        }
    }

    /// Updates the model in the list with new status after download/update
    private func updateModelStyleStatus(from modelStyle: ModelStyle) {
        if let index = models.firstIndex(where: { $0.name == modelStyle.name }) {
            models[index] = modelStyle
        }
    }
}
