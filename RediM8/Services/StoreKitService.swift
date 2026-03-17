import Foundation
import StoreKit

enum ProProductID: String, CaseIterable {
    case monthly = "au.com.redim8.pro.monthly"
    case annual = "au.com.redim8.pro.annual"
    case lifetime = "au.com.redim8.pro.lifetime"
}

enum ProEntitlement: Equatable {
    case free
    case pro(expiresAt: Date?)
    case emergencyUnlock

    var isPro: Bool {
        switch self {
        case .free: false
        case .pro, .emergencyUnlock: true
        }
    }
}

enum PurchaseError: LocalizedError {
    case productNotFound
    case purchaseFailed
    case purchaseCancelled
    case purchasePending
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .productNotFound: "Product not found. Please try again later."
        case .purchaseFailed: "Purchase could not be completed. Please try again."
        case .purchaseCancelled: "Purchase was cancelled."
        case .purchasePending: "Purchase is pending approval."
        case .verificationFailed: "Purchase verification failed. Please contact support."
        }
    }
}

@MainActor
final class StoreKitService: ObservableObject {
    @Published private(set) var products: [ProProductID: Product] = [:]
    @Published private(set) var entitlement: ProEntitlement = .free
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Product Loading

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let ids = Set(ProProductID.allCases.map(\.rawValue))
            let storeProducts = try await Product.products(for: ids)
            var mapped: [ProProductID: Product] = [:]
            for product in storeProducts {
                if let id = ProProductID(rawValue: product.id) {
                    mapped[id] = product
                }
            }
            products = mapped
        } catch {
            #if DEBUG
            print("[StoreKitService] Failed to load products: \(error)")
            #endif
            errorMessage = "Unable to load pricing. Please check your connection."
        }
    }

    // MARK: - Purchase

    func purchase(_ productID: ProProductID) async throws {
        guard let product = products[productID] else {
            throw PurchaseError.productNotFound
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            throw PurchaseError.purchaseFailed
        }

        switch result {
        case .success(let verification):
            let transaction = try checkVerification(verification)
            await refreshEntitlement()
            await transaction.finish()

        case .userCancelled:
            throw PurchaseError.purchaseCancelled

        case .pending:
            throw PurchaseError.purchasePending

        @unknown default:
            throw PurchaseError.purchaseFailed
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            errorMessage = "Unable to restore purchases. Please try again."
        }
    }

    // MARK: - Entitlement

    func refreshEntitlement() async {
        var foundEntitlement: ProEntitlement = .free

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerification(result) {
                if ProProductID(rawValue: transaction.productID) != nil {
                    let expiresAt = transaction.expirationDate
                    foundEntitlement = .pro(expiresAt: expiresAt)
                    break
                }
            }
        }

        entitlement = foundEntitlement
    }

    func applyEmergencyUnlock() {
        if entitlement == .free {
            entitlement = .emergencyUnlock
        }
    }

    func clearEmergencyUnlock() {
        if entitlement == .emergencyUnlock {
            entitlement = .free
        }
    }

    // MARK: - Helpers

    func displayPrice(for productID: ProProductID) -> String? {
        products[productID]?.displayPrice
    }

    // MARK: - Private

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self?.refreshEntitlement()
                    await transaction.finish()
                }
            }
        }
    }

    private nonisolated func checkVerification(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw PurchaseError.verificationFailed
        }
    }
}
