import Combine
import Foundation

@MainActor
final class VaultSystem: ObservableObject, AppSystem {
    @Published private(set) var isUnlocked: Bool
    @Published private(set) var state: VaultState

    let documentVaultService: DocumentVaultService

    private var cancellables = Set<AnyCancellable>()

    init(documentVaultService: DocumentVaultService) {
        self.documentVaultService = documentVaultService
        isUnlocked = documentVaultService.isUnlocked
        state = documentVaultService.state

        documentVaultService.$isUnlocked
            .assign(to: &$isUnlocked)

        documentVaultService.$state
            .assign(to: &$state)
    }

    func start() {}

    func stop() {}

    func lock() {
        documentVaultService.lock()
    }
}
