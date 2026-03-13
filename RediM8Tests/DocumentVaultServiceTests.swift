import LocalAuthentication
import XCTest
@testable import RediM8

@MainActor
final class DocumentVaultServiceTests: XCTestCase {
    func testUnlockAndSaveEmergencyInfoPersistsAcrossLockCycle() async throws {
        let service = makeService(testName: #function)

        try await service.unlock()
        try service.saveEmergencyInfo(
            EmergencyInfoCard(
                bloodType: "O+",
                allergies: "Penicillin",
                medications: "Ventolin",
                emergencyContacts: "Alex 0400 123 456",
                medicalNotes: "Asthma"
            )
        )
        service.lock()

        try await service.unlock()

        XCTAssertEqual(service.state.emergencyInfo.bloodType, "O+")
        XCTAssertEqual(service.state.emergencyInfo.medicalNotes, "Asthma")
    }

    func testAddedDocumentIsEncryptedAndRecoverable() async throws {
        let baseURL = makeBaseURL(testName: #function)
        let service = makeService(baseURL: baseURL)
        try await service.unlock()

        let payload = VaultImportPayload(
            data: Data("licence-data".utf8),
            displayName: "Driver Licence",
            filename: "licence.pdf",
            contentType: .pdf,
            source: .pdfImport,
            pageCount: 1
        )
        try service.addDocument(payload, to: .identity)

        let document = try XCTUnwrap(service.documents(in: .identity).first)
        let encryptedFileURL = baseURL.appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(document.id.uuidString)
            .appendingPathExtension(document.fileExtension)

        let encryptedData = try Data(contentsOf: encryptedFileURL)
        XCTAssertNotEqual(encryptedData, payload.data)

        let previewURL = try service.temporaryPreviewURL(for: document)
        let previewData = try Data(contentsOf: previewURL)
        XCTAssertEqual(previewData, payload.data)
    }

    func testDeleteDocumentRemovesStoredFile() async throws {
        let baseURL = makeBaseURL(testName: #function)
        let service = makeService(baseURL: baseURL)
        try await service.unlock()

        try service.addDocument(
            VaultImportPayload(
                data: Data("policy".utf8),
                displayName: "Insurance",
                filename: "policy.pdf",
                contentType: .pdf,
                source: .pdfImport,
                pageCount: 1
            ),
            to: .insurance
        )

        let document = try XCTUnwrap(service.documents(in: .insurance).first)
        let encryptedFileURL = baseURL.appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(document.id.uuidString)
            .appendingPathExtension(document.fileExtension)

        XCTAssertTrue(FileManager.default.fileExists(atPath: encryptedFileURL.path))
        try service.deleteDocument(document.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: encryptedFileURL.path))
    }

    private func makeBaseURL(testName: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("DocumentVaultServiceTests", isDirectory: true)
            .appendingPathComponent(testName.replacingOccurrences(of: " ", with: "_"), isDirectory: true)
    }

    private func makeService(testName: String) -> DocumentVaultService {
        makeService(baseURL: makeBaseURL(testName: testName))
    }

    private func makeService(baseURL: URL) -> DocumentVaultService {
        try? FileManager.default.removeItem(at: baseURL)
        return DocumentVaultService(
            baseURL: baseURL,
            authenticator: TestVaultAuthenticator(),
            keyProvider: FixedVaultKeyProvider(),
            fileManager: .default
        )
    }
}

private struct TestVaultAuthenticator: VaultAuthenticating {
    func authenticate(reason _: String) async throws -> LAContext {
        LAContext()
    }
}

private struct FixedVaultKeyProvider: VaultKeyProviding {
    func fetchOrCreateKey(using _: LAContext) throws -> Data {
        Data(repeating: 7, count: 32)
    }
}
