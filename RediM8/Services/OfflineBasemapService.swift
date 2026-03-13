import Foundation

@MainActor
final class OfflineBasemapService {
    struct Configuration: Equatable {
        enum Mode: Equatable {
            case premium(packageName: String)
            case fallback(reason: String)
        }

        let styleURL: URL
        let mode: Mode

        var isPremiumActive: Bool {
            if case .premium = mode {
                return true
            }
            return false
        }

        var statusMessage: String {
            switch mode {
            case let .premium(packageName):
                return "Premium offline basemap active: \(packageName)."
            case let .fallback(reason):
                return "Verified road/topographic basemap unavailable. \(reason)"
            }
        }
    }

    private enum AssetKey {
        static let directPathKeys: Set<String> = ["sprite", "glyphs", "url", "data"]
        static let tiles = "tiles"
    }

    private let bundle: Bundle
    private let fileManager: FileManager
    private let searchRoots: [URL]
    private let generatedStyleDirectory: URL
    private let explicitFallbackStyleURL: URL?
    private lazy var cachedConfiguration: Configuration = resolveConfiguration()

    init(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        searchRoots: [URL]? = nil,
        generatedStyleDirectory: URL? = nil,
        fallbackStyleURL: URL? = nil
    ) {
        self.bundle = bundle
        self.fileManager = fileManager
        self.searchRoots = searchRoots ?? Self.defaultSearchRoots(bundle: bundle, fileManager: fileManager)
        self.generatedStyleDirectory = generatedStyleDirectory ?? fileManager.temporaryDirectory.appendingPathComponent("RediM8OfflineBasemap", isDirectory: true)
        explicitFallbackStyleURL = fallbackStyleURL
    }

    var configuration: Configuration {
        cachedConfiguration
    }

    private func resolveConfiguration() -> Configuration {
        if let packageDirectory = premiumPackageDirectory() {
            do {
                return try premiumConfiguration(from: packageDirectory)
            } catch {
                return fallbackConfiguration(reason: "The local package at \(packageDirectory.lastPathComponent) is incomplete or invalid, so RediM8 is using the bundled tactical fallback instead of full cartography.")
            }
        }

        return fallbackConfiguration(reason: "No verified local tile package was found, so RediM8 is using the bundled tactical fallback instead of full cartography.")
    }

    private func premiumConfiguration(from packageDirectory: URL) throws -> Configuration {
        let styleTemplateURL = packageDirectory.appendingPathComponent("style.json")
        let styleData = try Data(contentsOf: styleTemplateURL)
        let jsonObject = try JSONSerialization.jsonObject(with: styleData)
        try validateAssetReferences(in: jsonObject, currentKey: nil, styleDirectory: packageDirectory)

        let rewrittenObject = rewriteAssetReferences(in: jsonObject, currentKey: nil, styleDirectory: packageDirectory)
        try fileManager.createDirectory(at: generatedStyleDirectory, withIntermediateDirectories: true, attributes: nil)

        let packageName = packageDisplayName(from: jsonObject, packageDirectory: packageDirectory)
        let sanitizedName = sanitizedFileName(packageDirectory.lastPathComponent)
        let generatedURL = generatedStyleDirectory.appendingPathComponent("\(sanitizedName)-style.json")
        let encodedStyle = try JSONSerialization.data(withJSONObject: rewrittenObject, options: [.prettyPrinted, .sortedKeys])
        try encodedStyle.write(to: generatedURL, options: .atomic)

        return Configuration(
            styleURL: generatedURL,
            mode: .premium(packageName: packageName)
        )
    }

    private func fallbackConfiguration(reason: String) -> Configuration {
        let resolvedFallbackURL = explicitFallbackStyleURL
            ?? bundledFallbackStyleURL()
            ?? writeEmergencyFallbackStyle()

        return Configuration(
            styleURL: resolvedFallbackURL,
            mode: .fallback(reason: reason)
        )
    }

    private func bundledFallbackStyleURL() -> URL? {
        let candidateURLs = [
            bundle.url(forResource: "RediM8MapStyle", withExtension: "json"),
            bundle.resourceURL?.appendingPathComponent("RediM8MapStyle.json"),
            bundle.bundleURL.appendingPathComponent("Resources", isDirectory: true).appendingPathComponent("RediM8MapStyle.json"),
            URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
                .appendingPathComponent("RediM8", isDirectory: true)
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("RediM8MapStyle.json"),
            Self.sourceTreeRoot().appendingPathComponent("Resources", isDirectory: true).appendingPathComponent("RediM8MapStyle.json")
        ]

        return candidateURLs.compactMap { $0 }.first { fileManager.fileExists(atPath: $0.path) }
    }

    private func writeEmergencyFallbackStyle() -> URL {
        try? fileManager.createDirectory(at: generatedStyleDirectory, withIntermediateDirectories: true, attributes: nil)
        let fallbackURL = generatedStyleDirectory.appendingPathComponent("emergency-fallback-style.json")
        let fallbackDocument: [String: Any] = [
            "version": 8,
            "name": "RediM8 Emergency Fallback",
            "center": [133.7751, -25.2744],
            "zoom": 3.1,
            "pitch": 0,
            "bearing": 0,
            "sources": [:],
            "layers": [
                [
                    "id": "background",
                    "type": "background",
                    "paint": [
                        "background-color": "#020805"
                    ]
                ]
            ]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: fallbackDocument, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: fallbackURL, options: .atomic)
        }
        return fallbackURL
    }

    private func premiumPackageDirectory() -> URL? {
        for root in searchRoots where fileManager.fileExists(atPath: root.path) {
            if fileManager.fileExists(atPath: root.appendingPathComponent("style.json").path) {
                return root
            }

            let children = (try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []

            for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                if fileManager.fileExists(atPath: child.appendingPathComponent("style.json").path) {
                    return child
                }
            }
        }

        return nil
    }

    private func validateAssetReferences(in value: Any, currentKey: String?, styleDirectory: URL) throws {
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary {
                try validateAssetReferences(in: child, currentKey: key, styleDirectory: styleDirectory)
            }
            return
        }

        if let array = value as? [Any] {
            if currentKey == AssetKey.tiles {
                for item in array {
                    guard let path = item as? String else { continue }
                    try validateRelativeAsset(path, key: AssetKey.tiles, styleDirectory: styleDirectory)
                }
                return
            }

            for child in array {
                try validateAssetReferences(in: child, currentKey: nil, styleDirectory: styleDirectory)
            }
            return
        }

        guard let path = value as? String,
              let currentKey,
              AssetKey.directPathKeys.contains(currentKey) else {
            return
        }

        try validateRelativeAsset(path, key: currentKey, styleDirectory: styleDirectory)
    }

    private func rewriteAssetReferences(in value: Any, currentKey: String?, styleDirectory: URL) -> Any {
        if let dictionary = value as? [String: Any] {
            var rewritten: [String: Any] = [:]
            for (key, child) in dictionary {
                rewritten[key] = rewriteAssetReferences(in: child, currentKey: key, styleDirectory: styleDirectory)
            }
            return rewritten
        }

        if let array = value as? [Any] {
            if currentKey == AssetKey.tiles {
                return array.map { item in
                    guard let path = item as? String else { return item }
                    return absoluteReference(for: path, relativeTo: styleDirectory)
                }
            }

            return array.map { rewriteAssetReferences(in: $0, currentKey: nil, styleDirectory: styleDirectory) }
        }

        guard let path = value as? String,
              let currentKey,
              AssetKey.directPathKeys.contains(currentKey) else {
            return value
        }

        return absoluteReference(for: path, relativeTo: styleDirectory)
    }

    private func validateRelativeAsset(_ reference: String, key: String, styleDirectory: URL) throws {
        guard !isAbsoluteReference(reference) else {
            return
        }

        switch key {
        case "sprite":
            let spriteBaseURL = resolvedURL(for: reference, relativeTo: styleDirectory)
            let jsonURL = spriteBaseURL.appendingPathExtension("json")
            let pngURL = spriteBaseURL.appendingPathExtension("png")
            guard fileManager.fileExists(atPath: jsonURL.path), fileManager.fileExists(atPath: pngURL.path) else {
                throw CocoaError(.fileNoSuchFile)
            }
        case "glyphs", AssetKey.tiles:
            let prefix = reference.split(separator: "{", maxSplits: 1).first.map(String.init) ?? reference
            let baseURL = resolvedURL(for: prefix, relativeTo: styleDirectory)
            guard fileManager.fileExists(atPath: baseURL.path) else {
                throw CocoaError(.fileNoSuchFile)
            }
        default:
            let assetURL = resolvedURL(for: reference, relativeTo: styleDirectory)
            guard fileManager.fileExists(atPath: assetURL.path) else {
                throw CocoaError(.fileNoSuchFile)
            }
        }
    }

    private func absoluteReference(for reference: String, relativeTo styleDirectory: URL) -> String {
        guard !isAbsoluteReference(reference) else {
            return reference
        }

        let absolutePath = resolvedURL(for: reference, relativeTo: styleDirectory).path
        var allowedCharacters = CharacterSet.urlPathAllowed
        allowedCharacters.insert(charactersIn: "{}")
        let encodedPath = absolutePath.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? absolutePath
        return "file://\(encodedPath)"
    }

    private func resolvedURL(for reference: String, relativeTo styleDirectory: URL) -> URL {
        let normalizedReference = reference.replacingOccurrences(of: "\\", with: "/")
        if normalizedReference.hasPrefix("/") {
            return URL(fileURLWithPath: normalizedReference, isDirectory: false)
        }

        let sanitizedReference = normalizedReference.hasPrefix("./")
            ? String(normalizedReference.dropFirst(2))
            : normalizedReference
        return URL(fileURLWithPath: sanitizedReference, relativeTo: styleDirectory).standardizedFileURL
    }

    private func isAbsoluteReference(_ reference: String) -> Bool {
        if reference.hasPrefix("/") {
            return true
        }

        return URL(string: reference)?.scheme != nil
    }

    private func packageDisplayName(from jsonObject: Any, packageDirectory: URL) -> String {
        if let dictionary = jsonObject as? [String: Any],
           let name = dictionary["name"] as? String,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }

        return packageDirectory.lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    private func sanitizedFileName(_ name: String) -> String {
        let disallowedCharacters = CharacterSet.alphanumerics.inverted
        let collapsed = name.components(separatedBy: disallowedCharacters).filter { !$0.isEmpty }.joined(separator: "-")
        return collapsed.isEmpty ? "offline-basemap" : collapsed.lowercased()
    }

    private static func defaultSearchRoots(bundle: Bundle, fileManager: FileManager) -> [URL] {
        let workspaceRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        let applicationSupportRoot = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ))?.appendingPathComponent("RediM8", isDirectory: true)

        let candidates: [URL?] = [
            bundle.resourceURL?.appendingPathComponent("OfflineBasemap", isDirectory: true),
            bundle.bundleURL.appendingPathComponent("Resources", isDirectory: true).appendingPathComponent("OfflineBasemap", isDirectory: true),
            workspaceRoot.appendingPathComponent("RediM8", isDirectory: true).appendingPathComponent("Resources", isDirectory: true).appendingPathComponent("OfflineBasemap", isDirectory: true),
            Self.sourceTreeRoot().appendingPathComponent("Resources", isDirectory: true).appendingPathComponent("OfflineBasemap", isDirectory: true),
            applicationSupportRoot?.appendingPathComponent("OfflineBasemap", isDirectory: true)
        ]

        var seenPaths = Set<String>()
        return candidates.compactMap { $0 }.filter { url in
            let standardizedPath = url.standardizedFileURL.path
            guard !seenPaths.contains(standardizedPath) else {
                return false
            }
            seenPaths.insert(standardizedPath)
            return true
        }
    }

    private static func sourceTreeRoot() -> URL {
        URL(fileURLWithPath: #filePath, isDirectory: false)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
