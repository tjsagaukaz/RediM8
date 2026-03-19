import CryptoKit
import Foundation
import LocalAuthentication
import Security

enum DocumentVaultError: LocalizedError {
    case locked
    case authenticationUnavailable(String)
    case authenticationFailed
    case invalidState
    case missingDocument
    case missingEmergencyInfo
    case encryptionFailed
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .locked:
            "Unlock Secure Vault before viewing or changing documents."
        case let .authenticationUnavailable(message):
            message
        case .authenticationFailed:
            "RediM8 could not confirm device ownership. Try Face ID, Touch ID, or passcode again."
        case .invalidState:
            "Secure Vault data could not be read."
        case .missingDocument:
            "That document is no longer available on this device."
        case .missingEmergencyInfo:
            "No responder emergency info is configured in Secure Vault yet."
        case let .importFailed(message):
            message
        case .encryptionFailed:
            "Secure Vault could not protect that file."
        }
    }
}

protocol VaultAuthenticating {
    func authenticate(reason: String) async throws -> LAContext
}

protocol VaultKeyProviding {
    func fetchOrCreateKey(using context: LAContext) throws -> Data
}

private struct DeviceOwnerAuthenticator: VaultAuthenticating {
    func authenticate(reason: String) async throws -> LAContext {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            let message = error?.localizedDescription ?? "Face ID, Touch ID, or device passcode is unavailable."
            throw DocumentVaultError.authenticationUnavailable(message)
        }

        let success = try await context.rediM8EvaluateDeviceOwnerAuthentication(reason: reason)
        guard success else {
            throw DocumentVaultError.authenticationFailed
        }

        return context
    }
}

private final class KeychainVaultKeyProvider: VaultKeyProviding {
    private enum Constants {
        static let service = "au.com.redim8.document-vault"
        static let account = "vault-key-v1"
        static let localizedReason = "Unlock Secure Vault"
    }

    func fetchOrCreateKey(using context: LAContext) throws -> Data {
        if let existing = try loadKey(using: context) {
            return existing
        }

        let newKey = Data((0..<32).map { _ in UInt8.random(in: 0...UInt8.max) })
        try storeKey(newKey)
        guard let persisted = try loadKey(using: context) else {
            throw DocumentVaultError.encryptionFailed
        }
        return persisted
    }

    private func storeKey(_ keyData: Data) throws {
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            &error
        ) else {
            let message = error?.takeRetainedValue().localizedDescription ?? "Unable to protect the vault key."
            throw DocumentVaultError.authenticationUnavailable(message)
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.service,
            kSecAttrAccount as String: Constants.account,
            kSecAttrAccessControl as String: accessControl,
            kSecUseDataProtectionKeychain as String: true,
            kSecValueData as String: keyData
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw DocumentVaultError.authenticationUnavailable(SecCopyErrorMessageString(status, nil) as String? ?? "Unable to save the vault key.")
        }
    }

    private func loadKey(using context: LAContext) throws -> Data? {
        context.localizedReason = Constants.localizedReason
        var item: CFTypeRef?
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.service,
            kSecAttrAccount as String: Constants.account,
            kSecUseDataProtectionKeychain as String: true,
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: context
        ]

        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw DocumentVaultError.authenticationUnavailable(SecCopyErrorMessageString(status, nil) as String? ?? "Unable to read the vault key.")
        }
    }
}

@MainActor
final class DocumentVaultService: ObservableObject {
    @Published private(set) var isUnlocked = false
    @Published private(set) var state: VaultState = .empty
    @Published private(set) var metadata: VaultMetadata = .empty

    private let authenticator: VaultAuthenticating
    private let keyProvider: VaultKeyProviding
    private let fileManager: FileManager
    private let baseURL: URL
    private let documentsDirectoryURL: URL
    private let previewDirectoryURL: URL
    private let stateFileURL: URL
    private let metadataFileURL: URL
    private var unlockedKey: SymmetricKey?
    private var previewURLs = Set<URL>()

    init(
        baseURL: URL? = nil,
        authenticator: VaultAuthenticating = DeviceOwnerAuthenticator(),
        keyProvider: VaultKeyProviding = KeychainVaultKeyProvider(),
        fileManager: FileManager = .default
    ) {
        self.authenticator = authenticator
        self.keyProvider = keyProvider
        self.fileManager = fileManager

        let resolvedBaseURL: URL
        if let baseURL {
            resolvedBaseURL = baseURL
        } else {
            let applicationSupportURL = try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            resolvedBaseURL = applicationSupportURL?
                .appendingPathComponent("RediM8Vault", isDirectory: true)
                ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("RediM8Vault", isDirectory: true)
        }

        self.baseURL = resolvedBaseURL
        documentsDirectoryURL = resolvedBaseURL.appendingPathComponent("Documents", isDirectory: true)
        previewDirectoryURL = fileManager.temporaryDirectory.appendingPathComponent("RediM8VaultPreview", isDirectory: true)
        stateFileURL = resolvedBaseURL.appendingPathComponent("vault_state.bin", isDirectory: false)
        metadataFileURL = resolvedBaseURL.appendingPathComponent("vault_metadata.json", isDirectory: false)

        do {
            try ensureStorageDirectories()
            metadata = try loadMetadata()
        } catch {
            RediLogger.vault.error("Failed to create vault storage directories: \(error.localizedDescription, privacy: .public)")
        }
    }

    deinit {
        let defaultFileManager = FileManager.default
        previewURLs.forEach { try? defaultFileManager.removeItem(at: $0) }
    }

    var categories: [VaultCategory] {
        VaultCategory.allCases
    }

    var quickAccessDocuments: [VaultDocument] {
        state.documents
            .filter(\.quickAccessEligible)
            .sorted { lhs, rhs in
                if lhs.category.quickAccessPriority != rhs.category.quickAccessPriority {
                    return lhs.category.quickAccessPriority < rhs.category.quickAccessPriority
                }
                return lhs.updatedAt > rhs.updatedAt
            }
            .prefix(4)
            .map { $0 }
    }

    func unlock() async throws {
        let context = try await authenticator.authenticate(reason: "Unlock Secure Vault for offline emergency documents.")
        let keyData = try keyProvider.fetchOrCreateKey(using: context)
        let key = SymmetricKey(data: keyData)
        try ensureStorageDirectories()
        unlockedKey = key
        state = try loadState(using: key)
        try refreshMetadataFromCurrentState(lastUpdatedAt: metadata.lastUpdatedAt)
        isUnlocked = true
    }

    func lock() {
        isUnlocked = false
        state = .empty
        unlockedKey = nil
        previewURLs.forEach { try? fileManager.removeItem(at: $0) }
        previewURLs.removeAll()
    }

    func accessResponderEmergencyInfo() async throws -> EmergencyInfoCard {
        let context = try await authenticator.authenticate(reason: "Access responder emergency info in Secure Vault.")
        let keyData = try keyProvider.fetchOrCreateKey(using: context)
        let key = SymmetricKey(data: keyData)
        try ensureStorageDirectories()
        let emergencyInfo = try loadState(using: key).emergencyInfo
        guard emergencyInfo.hasAnyContent else {
            throw DocumentVaultError.missingEmergencyInfo
        }
        return emergencyInfo
    }

    func categoryCount(_ category: VaultCategory) -> Int {
        state.documents.filter { $0.category == category }.count
    }

    func documents(in category: VaultCategory) -> [VaultDocument] {
        state.documents
            .filter { $0.category == category }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func addDocument(_ payload: VaultImportPayload, to category: VaultCategory) throws {
        let key = try requireUnlockedKey()
        try ensureStorageDirectories()

        let document = VaultDocument(
            id: UUID(),
            category: category,
            displayName: payload.displayName.nilIfBlank ?? payload.filename,
            originalFilename: payload.filename,
            fileExtension: payload.contentType.preferredFilenameExtension ?? URL(fileURLWithPath: payload.filename).pathExtension.nilIfBlank ?? "bin",
            contentTypeIdentifier: payload.contentType.identifier,
            source: payload.source,
            byteCount: payload.data.count,
            pageCount: payload.pageCount,
            createdAt: .now,
            updatedAt: .now
        )

        let encrypted = try encrypt(payload.data, using: key)
        try writeProtected(encrypted, to: documentURL(for: document))

        state.documents.removeAll { $0.id == document.id }
        state.documents.insert(document, at: 0)
        try persistState()
        try refreshMetadataFromCurrentState(lastUpdatedAt: document.updatedAt)
    }

    func deleteDocument(_ documentID: UUID) throws {
        _ = try requireUnlockedKey()
        guard let document = state.documents.first(where: { $0.id == documentID }) else {
            throw DocumentVaultError.missingDocument
        }

        state.documents.removeAll { $0.id == documentID }
        let encryptedFileURL = documentURL(for: document)
        if fileManager.fileExists(atPath: encryptedFileURL.path) {
            try fileManager.removeItem(at: encryptedFileURL)
        }
        try persistState()
        try refreshMetadataFromCurrentState(lastUpdatedAt: .now)
    }

    func saveEmergencyInfo(_ emergencyInfo: EmergencyInfoCard) throws {
        _ = try requireUnlockedKey()
        state.emergencyInfo = emergencyInfo
        try persistState()
        try refreshMetadataFromCurrentState(lastUpdatedAt: emergencyInfo.hasAnyContent ? .now : metadata.lastUpdatedAt)
    }

    func temporaryPreviewURL(for document: VaultDocument) throws -> URL {
        let key = try requireUnlockedKey()
        let encryptedURL = documentURL(for: document)
        guard fileManager.fileExists(atPath: encryptedURL.path) else {
            throw DocumentVaultError.missingDocument
        }

        let encryptedData = try Data(contentsOf: encryptedURL)
        let decryptedData = try decrypt(encryptedData, using: key)

        try ensureStorageDirectories()
        let sanitizedDisplayName = document.displayName.replacingOccurrences(of: "/", with: "-")

        let previewURL = previewDirectoryURL
            .appendingPathComponent("\(document.id.uuidString)-\(sanitizedDisplayName)", isDirectory: false)
            .appendingPathExtension(document.fileExtension)

        try writeProtected(decryptedData, to: previewURL)
        previewURLs.insert(previewURL)
        return previewURL
    }

    func releaseTemporaryPreviewURL(_ url: URL) {
        guard previewURLs.contains(url) else { return }
        try? fileManager.removeItem(at: url)
        previewURLs.remove(url)
    }

    private func persistState() throws {
        let key = try requireUnlockedKey()
        let data = try JSONEncoder.rediM8.encode(state)
        let encrypted = try encrypt(data, using: key)
        try writeProtected(encrypted, to: stateFileURL)
    }

    private func refreshMetadataFromCurrentState(lastUpdatedAt: Date?) throws {
        metadata = makeMetadata(from: state, lastUpdatedAt: lastUpdatedAt)
        try persistMetadata()
    }

    private func makeMetadata(from state: VaultState, lastUpdatedAt: Date?) -> VaultMetadata {
        let derivedLastUpdatedAt: Date?
        if state.documents.isEmpty, !state.emergencyInfo.hasAnyContent {
            derivedLastUpdatedAt = nil
        } else {
            derivedLastUpdatedAt = lastUpdatedAt ?? state.documents.map(\.updatedAt).max() ?? .now
        }

        return VaultMetadata(
            isIndexed: true,
            documentCount: state.documents.count,
            quickAccessCount: state.documents.filter(\.quickAccessEligible).count,
            hasEmergencyInfo: state.emergencyInfo.hasAnyContent,
            lastUpdatedAt: derivedLastUpdatedAt
        )
    }

    private func persistMetadata() throws {
        let data = try JSONEncoder.rediM8.encode(metadata)
        try writeProtected(data, to: metadataFileURL)
    }

    private func loadMetadata() throws -> VaultMetadata {
        guard fileManager.fileExists(atPath: metadataFileURL.path) else {
            return .empty
        }

        let data = try Data(contentsOf: metadataFileURL)
        guard !data.isEmpty else {
            return .empty
        }

        return try JSONDecoder.rediM8.decode(VaultMetadata.self, from: data)
    }

    private func loadState(using key: SymmetricKey) throws -> VaultState {
        guard fileManager.fileExists(atPath: stateFileURL.path) else {
            return .empty
        }

        let encryptedState = try Data(contentsOf: stateFileURL)
        guard !encryptedState.isEmpty else {
            return .empty
        }

        let decryptedState = try decrypt(encryptedState, using: key)
        return try JSONDecoder.rediM8.decode(VaultState.self, from: decryptedState)
    }

    private func requireUnlockedKey() throws -> SymmetricKey {
        guard let unlockedKey else {
            throw DocumentVaultError.locked
        }
        return unlockedKey
    }

    private func documentURL(for document: VaultDocument) -> URL {
        documentsDirectoryURL
            .appendingPathComponent(document.id.uuidString, isDirectory: false)
            .appendingPathExtension(document.fileExtension)
    }

    private func ensureStorageDirectories() throws {
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: documentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: previewDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableBaseURL = baseURL
        try mutableBaseURL.setResourceValues(values)

        try applyCompleteFileProtection(to: baseURL)
        try applyCompleteFileProtection(to: documentsDirectoryURL)
        try applyCompleteFileProtection(to: previewDirectoryURL)
    }

    private func writeProtected(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try applyCompleteFileProtection(to: url)
    }

    private func applyCompleteFileProtection(to url: URL) throws {
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
    }

    private func encrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        guard let combined = try AES.GCM.seal(data, using: key).combined else {
            throw DocumentVaultError.encryptionFailed
        }
        return combined
    }

    private func decrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }
}

private extension LAContext {
    func rediM8EvaluateDeviceOwnerAuthentication(reason: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }
}
