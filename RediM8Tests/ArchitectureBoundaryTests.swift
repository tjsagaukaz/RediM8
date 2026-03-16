import XCTest

final class ArchitectureBoundaryTests: XCTestCase {
    private let forbiddenReferencesByFile: [String: [String]] = [
        "PreparednessSystem.swift": ["AppState", "SignalSystem", "MapSystem", "VaultSystem", "PowerSystem"],
        "SignalSystem.swift": ["AppState", "PreparednessSystem", "MapSystem", "VaultSystem", "PowerSystem"],
        "MapSystem.swift": ["AppState", "PreparednessSystem", "SignalSystem", "VaultSystem", "PowerSystem"],
        "VaultSystem.swift": ["AppState", "PreparednessSystem", "SignalSystem", "MapSystem", "PowerSystem"],
        "PowerSystem.swift": ["AppState", "PreparednessSystem", "SignalSystem", "MapSystem", "VaultSystem"]
    ]

    func testSystemsDoNotReferenceSiblingSystemsOrAppState() throws {
        let systemsDirectory = try XCTUnwrap(repositoryRootURL()?.appendingPathComponent("RediM8/Systems", isDirectory: true))

        for (filename, forbiddenReferences) in forbiddenReferencesByFile {
            let fileURL = systemsDirectory.appendingPathComponent(filename)
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            let sanitizedContents = sanitizedSource(contents)

            for forbiddenReference in forbiddenReferences {
                XCTAssertFalse(
                    sanitizedContents.contains(word: forbiddenReference),
                    "\(filename) should not reference \(forbiddenReference) directly. Route cross-system coordination through AppState or a shared model/service."
                )
            }
        }
    }

    private func repositoryRootURL() -> URL? {
        var candidate = URL(fileURLWithPath: #filePath)
        while candidate.path != "/" {
            let proposedRoot = candidate.deletingLastPathComponent().deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: proposedRoot.appendingPathComponent("RediM8.xcodeproj").path) {
                return proposedRoot
            }
            candidate.deleteLastPathComponent()
        }
        return nil
    }

    private func sanitizedSource(_ source: String) -> String {
        source
            .replacingOccurrences(of: #"/\*[\s\S]*?\*/"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"//.*"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #""(?:\\.|[^"\\])*""#, with: "\"\"", options: .regularExpression)
    }
}

private extension String {
    func contains(word: String) -> Bool {
        range(of: #"\#(NSRegularExpression.escapedPattern(for: word))\b"#, options: .regularExpression) != nil
    }
}
