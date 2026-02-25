//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import Foundation
import Observation

import PersoInteractiveOnDeviceSDK

/// ViewModel for managing model selection and download state
@Observable
@MainActor
final class ModelSelectViewModel {

    // MARK: - Published Properties

    /// List of available model styles
    var models: [ModelStyle] = []

    /// Download/Update progress for each model item
    var itemsProgress: [String: Progress] = [:]

    /// Loading state
    var isLoading: Bool = false

    /// Error message if fetch fails
    var errorMessage: String?

    /// Error message if download fails
    var downloadError: String?

    /// Deleting state
    var isDeleting: Bool = false

    @ObservationIgnored private var downloadTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var completionPollingTasks: [String: Task<Void, Never>] = [:]

    private static let maxPollingAttempts = 6
    private static let pollingInterval: Duration = .milliseconds(700)

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

    /// Handles model selection - starts download for unavailable models
    func setItem(_ item: ModelSelectView.Item) {
        let modelStyle = item.modelStyle

        switch modelStyle.availability {
        case .available:
            break

        case .unavailable(_):
            downloadTasks[item.id]?.cancel()
            completionPollingTasks[item.id]?.cancel()
            completionPollingTasks[item.id] = nil
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
        cleanupDownloadState(for: itemID)
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
                    if progressObj.fractionCompleted >= 1.0 {
                        scheduleCompletionPolling(for: itemID, modelName: modelStyle.name)
                    }
                case .finished(let updatedModelStyle):
                    cleanupDownloadState(for: itemID)
                    updateModelStyleStatus(from: updatedModelStyle)
                }
            }

            // Stream이 .finished 없이 정상 종료된 경우 cleanup
            if self.itemsProgress[itemID] != nil {
                cleanupDownloadState(for: itemID)
                await fetchModelStyles()
            }

        } catch is CancellationError {
            cleanupDownloadState(for: itemID)
        } catch {
            cleanupDownloadState(for: itemID)
            downloadError = "Download failed: \(error.localizedDescription)"
        }
    }

    /// Updates the model in the list with new status after download/update
    private func updateModelStyleStatus(from modelStyle: ModelStyle) {
        if let index = models.firstIndex(where: { $0.name == modelStyle.name }) {
            models[index] = modelStyle
        }
    }

    private func scheduleCompletionPolling(for itemID: String, modelName: String) {
        guard completionPollingTasks[itemID] == nil else {
            return
        }

        completionPollingTasks[itemID] = Task {
            await pollCompletionStatus(for: itemID, modelName: modelName)
        }
    }

    private func pollCompletionStatus(for itemID: String, modelName: String) async {
        defer { completionPollingTasks[itemID] = nil }

        for _ in 0..<Self.maxPollingAttempts {
            guard !Task.isCancelled else { return }
            guard itemsProgress[itemID] != nil else { return }

            if let refreshedStyle = await fetchModelStyle(named: modelName),
               refreshedStyle.availability == .available {
                cleanupDownloadState(for: itemID)
                updateModelStyleStatus(from: refreshedStyle)
                return
            }

            try? await Task.sleep(for: Self.pollingInterval)
        }
    }

    private func cleanupDownloadState(for itemID: String) {
        itemsProgress[itemID] = nil
        downloadTasks[itemID]?.cancel()
        downloadTasks[itemID] = nil
        completionPollingTasks[itemID]?.cancel()
        completionPollingTasks[itemID] = nil
    }

    private func fetchModelStyle(named modelName: String) async -> ModelStyle? {
        do {
            let styles = try await PersoInteractive.fetchAvailableModelStyles()
            return styles.first(where: { $0.name == modelName })
        } catch {
            return nil
        }
    }
}
