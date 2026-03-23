import CryptoKit
import Foundation
import Security

enum SecureStoreError: LocalizedError {
    case keyUnavailable(String)
    case encryptionFailed
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case let .keyUnavailable(message):
            message
        case .encryptionFailed:
            "Secure storage encryption failed."
        case .decryptionFailed:
            "Secure storage decryption failed."
        }
    }
}

protocol SecureStoreKeyProviding {
    func fetchOrCreateKey() throws -> Data
}

private final class KeychainSecureStoreKeyProvider: SecureStoreKeyProviding {
    private enum Constants {
        static let service = "au.com.redim8.secure-store"
    }

    private let account: String
    private let fallbackKeyProvider: FileProtectedSecureStoreKeyProvider

    init(namespace: String, fileManager: FileManager = .default) {
        account = "key.\(Self.sanitizedNamespace(namespace))"
        fallbackKeyProvider = FileProtectedSecureStoreKeyProvider(namespace: namespace, fileManager: fileManager)
    }

    func fetchOrCreateKey() throws -> Data {
        do {
            if let existingKey = try loadKey() {
                return existingKey
            }

            let generatedKey = Data((0..<32).map { _ in UInt8.random(in: 0...UInt8.max) })
            try storeKey(generatedKey)
            return generatedKey
        } catch SecureStoreError.keyUnavailable {
            return try fallbackKeyProvider.fetchOrCreateKey()
        }
    }

    private func storeKey(_ keyData: Data) throws {
        let primaryStatus = storeKey(keyData, useDataProtectionKeychain: true)
        guard primaryStatus != errSecSuccess else {
            return
        }

        if Self.shouldRetryWithoutDataProtectionKeychain(status: primaryStatus) {
            let fallbackStatus = storeKey(keyData, useDataProtectionKeychain: false)
            guard fallbackStatus == errSecSuccess else {
                throw SecureStoreError.keyUnavailable(
                    SecCopyErrorMessageString(fallbackStatus, nil) as String? ?? "Unable to save the secure storage key."
                )
            }
            return
        }

        throw SecureStoreError.keyUnavailable(
            SecCopyErrorMessageString(primaryStatus, nil) as String? ?? "Unable to save the secure storage key."
        )
    }

    private func loadKey() throws -> Data? {
        let primaryResult = try loadKey(useDataProtectionKeychain: true)
        switch primaryResult {
        case let .success(data):
            return data
        case .notFound:
            return nil
        case let .failure(status):
            if Self.shouldRetryWithoutDataProtectionKeychain(status: status) {
                let fallbackResult = try loadKey(useDataProtectionKeychain: false)
                switch fallbackResult {
                case let .success(data):
                    return data
                case .notFound:
                    return nil
                case let .failure(fallbackStatus):
                    throw SecureStoreError.keyUnavailable(
                        SecCopyErrorMessageString(fallbackStatus, nil) as String? ?? "Unable to read the secure storage key."
                    )
                }
            }

            throw SecureStoreError.keyUnavailable(
                SecCopyErrorMessageString(status, nil) as String? ?? "Unable to read the secure storage key."
            )
        }
    }

    private func storeKey(_ keyData: Data, useDataProtectionKeychain: Bool) -> OSStatus {
        let baseQuery = keychainQuery(useDataProtectionKeychain: useDataProtectionKeychain)
        let addQuery = baseQuery.merging([
            kSecValueData as String: keyData
        ]) { _, new in new }

        SecItemDelete(baseQuery as CFDictionary)
        return SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadKey(useDataProtectionKeychain: Bool) throws -> KeychainLookupResult {
        var item: CFTypeRef?
        let query = keychainQuery(useDataProtectionKeychain: useDataProtectionKeychain).merging([
            kSecReturnData as String: true
        ]) { _, new in new }

        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return .success(item as? Data)
        case errSecItemNotFound:
            return .notFound
        default:
            return .failure(status)
        }
    }

    private func keychainQuery(useDataProtectionKeychain: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        if useDataProtectionKeychain {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }

    private static func shouldRetryWithoutDataProtectionKeychain(status: OSStatus) -> Bool {
        status == errSecMissingEntitlement
    }

    private enum KeychainLookupResult {
        case success(Data?)
        case notFound
        case failure(OSStatus)
    }

    private static func sanitizedNamespace(_ namespace: String) -> String {
        let filtered = namespace
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .lowercased()
        return filtered.isEmpty ? "default" : filtered
    }
}

private final class FileProtectedSecureStoreKeyProvider: SecureStoreKeyProviding {
    private let fileManager: FileManager
    private let baseURL: URL

    init(namespace: String, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        baseURL = Self.defaultBaseURL(fileManager: fileManager, namespace: namespace)
    }

    func fetchOrCreateKey() throws -> Data {
        let url = keyURL
        if fileManager.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            guard data.count == 32 else {
                throw SecureStoreError.keyUnavailable("Stored secure storage key is invalid.")
            }
            return data
        }

        try ensureStorageDirectory()
        let keyData = Data((0..<32).map { _ in UInt8.random(in: 0...UInt8.max) })
        try keyData.write(to: url, options: .atomic)
        try applyCompleteFileProtection(to: url)
        return keyData
    }

    private var keyURL: URL {
        baseURL.appendingPathComponent("key.bin", isDirectory: false)
    }

    private func ensureStorageDirectory() throws {
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableBaseURL = baseURL
        try mutableBaseURL.setResourceValues(values)

        try applyCompleteFileProtection(to: baseURL)
    }

    private func applyCompleteFileProtection(to url: URL) throws {
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
    }

    private static func defaultBaseURL(fileManager: FileManager, namespace: String) -> URL {
        let applicationSupportURL = RediLogger.persistence.tryOrDefault(
            URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
            "Resolve app support for secure keys"
        ) {
            try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }

        return applicationSupportURL
            .appendingPathComponent("RediM8SecureKeys", isDirectory: true)
            .appendingPathComponent(sanitizedNamespace(namespace), isDirectory: true)
    }

    private static func sanitizedNamespace(_ namespace: String) -> String {
        let filtered = namespace
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .lowercased()
        return filtered.isEmpty ? "default" : filtered
    }
}

final class SecureStore {
    private let keyProvider: SecureStoreKeyProviding
    private let fileManager: FileManager
    private let baseURL: URL

    init(
        namespace: String,
        baseURL: URL? = nil,
        keyProvider: SecureStoreKeyProviding? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.baseURL = baseURL ?? Self.defaultBaseURL(fileManager: fileManager, namespace: namespace)
        self.keyProvider = keyProvider ?? KeychainSecureStoreKeyProvider(namespace: namespace, fileManager: fileManager)
    }

    func save<T: Encodable>(_ value: T, for key: String) throws {
        try ensureStorageDirectory()
        let encodedValue = try JSONEncoder.rediM8.encode(value)
        let encryptedValue = try encrypt(encodedValue)
        try writeProtected(encryptedValue, to: fileURL(for: key))
    }

    func load<T: Decodable>(_ type: T.Type, for key: String) throws -> T? {
        let url = fileURL(for: key)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        let encryptedValue = try Data(contentsOf: url)
        guard !encryptedValue.isEmpty else {
            return nil
        }

        let decryptedValue = try decrypt(encryptedValue)
        return try JSONDecoder.rediM8.decode(type, from: decryptedValue)
    }

    func deleteValue(for key: String) throws {
        let url = fileURL(for: key)
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try fileManager.removeItem(at: url)
    }

    func containsValue(for key: String) -> Bool {
        fileManager.fileExists(atPath: fileURL(for: key).path)
    }

    private func ensureStorageDirectory() throws {
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableBaseURL = baseURL
        try mutableBaseURL.setResourceValues(values)

        try applyCompleteFileProtection(to: baseURL)
    }

    private func fileURL(for key: String) -> URL {
        baseURL
            .appendingPathComponent(Self.hashedKey(key), isDirectory: false)
            .appendingPathExtension("bin")
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

    private func encrypt(_ data: Data) throws -> Data {
        let keyData = try keyProvider.fetchOrCreateKey()
        let key = SymmetricKey(data: keyData)

        guard let combined = try AES.GCM.seal(data, using: key).combined else {
            throw SecureStoreError.encryptionFailed
        }

        return combined
    }

    private func decrypt(_ data: Data) throws -> Data {
        let keyData = try keyProvider.fetchOrCreateKey()
        let key = SymmetricKey(data: keyData)

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw SecureStoreError.decryptionFailed
        }
    }

    private static func defaultBaseURL(fileManager: FileManager, namespace: String) -> URL {
        let applicationSupportURL = RediLogger.persistence.tryOrDefault(
            URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
            "Resolve app support for secure store"
        ) {
            try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }

        return applicationSupportURL
            .appendingPathComponent("RediM8Secure", isDirectory: true)
            .appendingPathComponent(sanitizedNamespace(namespace), isDirectory: true)
    }

    private static func hashedKey(_ key: String) -> String {
        let digest = SHA256.hash(data: Data(key.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func sanitizedNamespace(_ namespace: String) -> String {
        let filtered = namespace
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .lowercased()
        return filtered.isEmpty ? "default" : filtered
    }
}
