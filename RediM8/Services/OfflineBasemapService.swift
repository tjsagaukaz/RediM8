import Combine
import Foundation

@MainActor
final class OfflineBasemapService: ObservableObject {
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
                return "Local offline basemap active: \(packageName)."
            case let .fallback(reason):
                return "Local road/topographic basemap unavailable. \(reason)"
            }
        }
    }

    struct InstalledPackage: Identifiable, Equatable {
        let id: String
        let name: String
        let summary: String
        let version: String
        let installedAt: Date
        let sizeBytes: Int64
        let sourceManifestURL: URL?
        let directoryURL: URL
        let isActive: Bool

        var sizeText: String {
            ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
        }
    }

    private struct DownloadManifest: Decodable {
        let package: PackageDescriptor
        let files: [FileDescriptor]
    }

    private struct PackageDescriptor: Decodable {
        let id: String
        let name: String
        let summary: String
        let version: String

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case summary
            case subtitle
            case description
            case version
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0"
            summary = try container.decodeIfPresent(String.self, forKey: .summary)
                ?? container.decodeIfPresent(String.self, forKey: .subtitle)
                ?? container.decodeIfPresent(String.self, forKey: .description)
                ?? "Downloaded offline basemap package."
        }
    }

    private struct FileDescriptor: Decodable {
        let path: String
        let url: URL
    }

    private struct InstalledPackageMetadata: Codable {
        let id: String
        let name: String
        let summary: String
        let version: String
        let installedAt: Date
        let sourceManifestURL: String?
    }

    private enum AssetKey {
        static let directPathKeys: Set<String> = ["sprite", "glyphs", "url", "data"]
        static let tiles = "tiles"
    }

    private enum Constants {
        static let metadataFilename = ".redim8-basemap-package.json"
        static let activePackageFilename = ".redim8-active-package"
    }

    private let bundle: Bundle
    private let fileManager: FileManager
    private let searchRoots: [URL]
    private let generatedStyleDirectory: URL
    private let explicitFallbackStyleURL: URL?
    private let managedPackageRoot: URL
    private let activePackageFileURL: URL
    private let catalog: OfflineBasemapCatalog

    @Published private(set) var configuration: Configuration
    @Published private(set) var installedPackages: [InstalledPackage] = []
    @Published private(set) var catalogPackages: [OfflineBasemapCatalogPackage] = []
    @Published private(set) var isInstalling = false
    @Published private(set) var installStatusText: String?
    @Published private(set) var installErrorText: String?

    init(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        searchRoots: [URL]? = nil,
        generatedStyleDirectory: URL? = nil,
        fallbackStyleURL: URL? = nil
    ) {
        self.bundle = bundle
        self.fileManager = fileManager
        let resolvedManagedRoot = Self.managedPackageRoot(fileManager: fileManager)
        self.searchRoots = searchRoots ?? Self.defaultSearchRoots(
            bundle: bundle,
            fileManager: fileManager,
            managedPackageRoot: resolvedManagedRoot
        )
        self.generatedStyleDirectory = generatedStyleDirectory
            ?? fileManager.temporaryDirectory.appendingPathComponent("RediM8OfflineBasemap", isDirectory: true)
        explicitFallbackStyleURL = fallbackStyleURL
        managedPackageRoot = resolvedManagedRoot
        activePackageFileURL = resolvedManagedRoot.appendingPathComponent(Constants.activePackageFilename)
        do {
            catalog = try bundle.decode("BasemapCatalog.json", as: OfflineBasemapCatalog.self)
        } catch {
            RediLogger.basemap.error("Failed to decode BasemapCatalog.json: \(error.localizedDescription)")
            catalog = OfflineBasemapCatalog(lastUpdated: .distantPast, packages: [])
        }

        configuration = Configuration(
            styleURL: fallbackStyleURL ?? self.generatedStyleDirectory,
            mode: .fallback(reason: "Loading offline basemap configuration.")
        )
        catalogPackages = catalog.packages.sorted(by: Self.catalogSort)

        refreshInstalledPackages()
        refreshConfiguration()
    }

    var catalogLastUpdated: Date {
        catalog.lastUpdated
    }

    func installPackage(from manifestURL: URL) async {
        guard !isInstalling else {
            return
        }

        isInstalling = true
        installErrorText = nil
        installStatusText = "Fetching basemap manifest..."

        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("RediM8BasemapInstall-\(UUID().uuidString)", isDirectory: true)

        defer {
            try? fileManager.removeItem(at: temporaryDirectory)
            isInstalling = false
        }

        do {
            try validateTrustedRemoteURL(manifestURL, label: "manifest")
            try ensureManagedPackageRoot()

            let manifestData = try await fetchData(from: manifestURL)
            let manifest = try JSONDecoder().decode(DownloadManifest.self, from: manifestData)
            guard manifest.files.contains(where: { normalizedRelativePath($0.path) == "style.json" }) else {
                throw CocoaError(.fileReadCorruptFile, userInfo: [NSLocalizedDescriptionKey: "The basemap manifest must include a root-level style.json file."])
            }

            try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true, attributes: nil)

            for (index, file) in manifest.files.enumerated() {
                installStatusText = "Downloading \(index + 1) of \(manifest.files.count): \(file.path)"
                let sourceURL = resolvedRemoteURL(for: file.url, relativeTo: manifestURL)
                try validateTrustedRemoteURL(sourceURL, label: "package file")
                try await downloadFile(from: sourceURL, toRelativePath: file.path, inside: temporaryDirectory)
            }

            let downloadedStyleURL = temporaryDirectory.appendingPathComponent("style.json")
            guard fileManager.fileExists(atPath: downloadedStyleURL.path) else {
                throw CocoaError(.fileNoSuchFile, userInfo: [NSLocalizedDescriptionKey: "Downloaded package is missing style.json after installation."])
            }

            let metadata = InstalledPackageMetadata(
                id: manifest.package.id,
                name: manifest.package.name,
                summary: manifest.package.summary,
                version: manifest.package.version,
                installedAt: .now,
                sourceManifestURL: manifestURL.absoluteString
            )
            try writeMetadata(metadata, inside: temporaryDirectory)

            let destinationDirectory = managedPackageRoot.appendingPathComponent(sanitizedFileName(manifest.package.id), isDirectory: true)
            if fileManager.fileExists(atPath: destinationDirectory.path) {
                try fileManager.removeItem(at: destinationDirectory)
            }
            try fileManager.moveItem(at: temporaryDirectory, to: destinationDirectory)
            try excludeFromBackup(destinationDirectory)

            saveActivePackageID(manifest.package.id)
            refreshInstalledPackages()
            refreshConfiguration()
            installStatusText = "Installed \(manifest.package.name)."
        } catch {
            installErrorText = readableError(from: error)
            installStatusText = nil
        }
    }

    func installCatalogPackage(_ package: OfflineBasemapCatalogPackage) async {
        guard package.availability == .availableNow else {
            installStatusText = nil
            installErrorText = "This basemap is listed in the catalog, but the hosted package is not live yet."
            return
        }

        guard let manifestURL = manifestURL(for: package) else {
            installStatusText = nil
            installErrorText = "The selected basemap package does not include a usable manifest reference."
            return
        }

        await installPackage(from: manifestURL)
    }

    func activatePackage(_ packageID: String) {
        guard installedPackages.contains(where: { $0.id == packageID }) else {
            return
        }
        saveActivePackageID(packageID)
        installErrorText = nil
        installStatusText = "Activated offline basemap."
        refreshInstalledPackages()
        refreshConfiguration()
    }

    func removePackage(_ packageID: String) {
        guard let package = installedPackages.first(where: { $0.id == packageID }) else {
            return
        }

        do {
            if fileManager.fileExists(atPath: package.directoryURL.path) {
                try fileManager.removeItem(at: package.directoryURL)
            }
            let nextActivePackageID: String?
            if activePackageID() == packageID {
                nextActivePackageID = installedPackages.first(where: { $0.id != packageID })?.id
            } else {
                nextActivePackageID = activePackageID()
            }
            saveActivePackageID(nextActivePackageID)
            installErrorText = nil
            installStatusText = nextActivePackageID == nil
                ? "Removed basemap package. Tactical fallback is active."
                : "Removed basemap package."
            refreshInstalledPackages()
            refreshConfiguration()
        } catch {
            installErrorText = readableError(from: error)
        }
    }

    func clearInstallFeedback() {
        installStatusText = nil
        installErrorText = nil
    }

    func refreshConfiguration() {
        configuration = resolveConfiguration()
    }

    #if DEBUG
    func seedForTesting(configuration: Configuration) {
        self.configuration = configuration
        installStatusText = nil
        installErrorText = nil
        isInstalling = false
    }
    #endif

    private func refreshInstalledPackages() {
        let activeID = activePackageID()
        guard fileManager.fileExists(atPath: managedPackageRoot.path) else {
            installedPackages = []
            return
        }

        let packageDirectories = (RediLogger.basemap.tryOrDefault([], "List managed packages") {
            try fileManager.contentsOfDirectory(
                at: managedPackageRoot,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        })
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            }

        installedPackages = packageDirectories.compactMap { directoryURL in
            let styleURL = directoryURL.appendingPathComponent("style.json")
            guard fileManager.fileExists(atPath: styleURL.path) else {
                return nil
            }

            let metadata = loadMetadata(from: directoryURL)
            let packageID = metadata?.id ?? directoryURL.lastPathComponent
            let packageName = metadata?.name ?? directoryURL.lastPathComponent.replacingOccurrences(of: "-", with: " ").capitalized
            let summary = metadata?.summary ?? "Downloaded offline basemap package."
            let version = metadata?.version ?? "Custom"
            let installedAt = metadata?.installedAt ?? directoryInstalledDate(for: directoryURL)
            let sourceManifestURL = metadata?.sourceManifestURL.flatMap(URL.init(string:))
            let byteCount = directoryByteCount(at: directoryURL)

            return InstalledPackage(
                id: packageID,
                name: packageName,
                summary: summary,
                version: version,
                installedAt: installedAt,
                sizeBytes: byteCount,
                sourceManifestURL: sourceManifestURL,
                directoryURL: directoryURL,
                isActive: packageID == activeID
            )
        }
        .sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive {
                return lhs.isActive
            }
            return lhs.installedAt > rhs.installedAt
        }
    }

    private func resolveConfiguration() -> Configuration {
        if let packageDirectory = activePackageDirectory() ?? premiumPackageDirectory() {
            do {
                return try premiumConfiguration(from: packageDirectory)
            } catch {
                let packageName = packageDirectory.lastPathComponent
                return fallbackConfiguration(reason: "The local package at \(packageName) is incomplete or invalid, so RediM8 is using the bundled tactical fallback instead of full cartography.")
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
        // When an explicit fallback URL was provided (e.g. in tests), honour it
        // directly — don't rewrite through the australia path.
        if let explicit = explicitFallbackStyleURL {
            return Configuration(
                styleURL: explicit,
                mode: .fallback(reason: reason)
            )
        }

        if let australiaConfig = australiaFallbackConfiguration(reason: reason) {
            return australiaConfig
        }

        let resolvedFallbackURL = bundledFallbackStyleURL()
            ?? writeEmergencyFallbackStyle()

        return Configuration(
            styleURL: resolvedFallbackURL,
            mode: .fallback(reason: reason)
        )
    }

    private func australiaFallbackConfiguration(reason: String) -> Configuration? {
        // Resources are copied flat into the bundle — style and GeoJSON files
        // sit alongside each other in the bundle's resource directory.
        guard let styleURL = bundle.url(forResource: "australia-fallback-style", withExtension: "json")
                ?? bundle.resourceURL?.appendingPathComponent("australia-fallback-style.json"),
              fileManager.fileExists(atPath: styleURL.path)
        else {
            return nil
        }

        let directory = styleURL.deletingLastPathComponent()

        do {
            let styleData = try Data(contentsOf: styleURL)
            let jsonObject = try JSONSerialization.jsonObject(with: styleData)
            let rewritten = rewriteAssetReferences(in: jsonObject, currentKey: nil, styleDirectory: directory)

            try fileManager.createDirectory(at: generatedStyleDirectory, withIntermediateDirectories: true, attributes: nil)
            let generatedURL = generatedStyleDirectory.appendingPathComponent("australia-fallback-rewritten.json")
            let encoded = try JSONSerialization.data(withJSONObject: rewritten, options: [.prettyPrinted, .sortedKeys])
            try encoded.write(to: generatedURL, options: .atomic)

            return Configuration(
                styleURL: generatedURL,
                mode: .fallback(reason: "\(reason) Using low-resolution Australia basemap.")
            )
        } catch {
            return nil
        }
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
        RediLogger.basemap.tryOrNil("Create fallback style directory") {
            try fileManager.createDirectory(at: generatedStyleDirectory, withIntermediateDirectories: true, attributes: nil)
        }
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

        if let data = RediLogger.basemap.tryOrNil("Serialize fallback style", operation: {
            try JSONSerialization.data(withJSONObject: fallbackDocument, options: [.prettyPrinted, .sortedKeys])
        }) {
            RediLogger.basemap.tryOrNil("Write fallback style") { try data.write(to: fallbackURL, options: .atomic) }
        }
        return fallbackURL
    }

    private func premiumPackageDirectory() -> URL? {
        for root in searchRoots where fileManager.fileExists(atPath: root.path) {
            if isManagedPackageRoot(root) {
                continue
            }

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

    private func activePackageDirectory() -> URL? {
        if let activeID = activePackageID(),
           let package = installedPackages.first(where: { $0.id == activeID }) {
            return package.directoryURL
        }

        return installedPackages.first?.directoryURL
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

        return loadMetadata(from: packageDirectory)?.name
            ?? packageDirectory.lastPathComponent
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
    }

    private func sanitizedFileName(_ name: String) -> String {
        let disallowedCharacters = CharacterSet.alphanumerics.inverted
        let collapsed = name.components(separatedBy: disallowedCharacters).filter { !$0.isEmpty }.joined(separator: "-")
        return collapsed.isEmpty ? "offline-basemap" : collapsed.lowercased()
    }

    // Network methods removed — offline architecture.
    // Basemap packages must be pre-installed via bundled resources or side-loading.

    private func fetchData(from url: URL) async throws -> Data {
        // Offline-only: only file:// URLs are supported
        guard url.isFileURL else {
            throw CocoaError(
                .fileReadUnsupportedScheme,
                userInfo: [NSLocalizedDescriptionKey: "Network downloads are disabled. Only local file URLs are supported."]
            )
        }
        return try Data(contentsOf: url)
    }

    private func downloadFile(from url: URL, toRelativePath relativePath: String, inside rootDirectory: URL) async throws {
        guard url.isFileURL else {
            throw CocoaError(
                .fileReadUnsupportedScheme,
                userInfo: [NSLocalizedDescriptionKey: "Network downloads are disabled. Only local file URLs are supported."]
            )
        }
        let destinationURL = try destinationURL(for: relativePath, inside: rootDirectory)
        try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: url, to: destinationURL)
    }

    private func validateTrustedRemoteURL(_ url: URL, label: String) throws {
        guard url.isFileURL else {
            throw CocoaError(
                .fileReadUnsupportedScheme,
                userInfo: [NSLocalizedDescriptionKey: "Network access is disabled. The basemap \(label) must be a local file."]
            )
        }
    }

    private func resolvedRemoteURL(for fileURL: URL, relativeTo manifestURL: URL) -> URL {
        if fileURL.scheme != nil {
            return fileURL
        }

        let baseURL = manifestURL.deletingLastPathComponent()
        return URL(string: fileURL.relativeString, relativeTo: baseURL)?.absoluteURL
            ?? baseURL.appendingPathComponent(fileURL.relativeString)
    }

    private func manifestURL(for package: OfflineBasemapCatalogPackage) -> URL? {
        guard let reference = package.manifestReference?.nilIfBlank else {
            return nil
        }

        if let absoluteURL = URL(string: reference), absoluteURL.scheme != nil {
            return absoluteURL
        }

        let candidateURLs = [
            bundle.resourceURL?.appendingPathComponent(reference),
            bundle.bundleURL.appendingPathComponent(reference),
            bundle.resourceURL?.appendingPathComponent("Data", isDirectory: true).appendingPathComponent(reference),
            bundle.bundleURL.appendingPathComponent("Data", isDirectory: true).appendingPathComponent(reference),
            URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
                .appendingPathComponent("RediM8", isDirectory: true)
                .appendingPathComponent("Data", isDirectory: true)
                .appendingPathComponent(reference),
            Self.sourceTreeRoot().appendingPathComponent("Data", isDirectory: true).appendingPathComponent(reference)
        ]

        return candidateURLs.compactMap { $0 }.first { fileManager.fileExists(atPath: $0.path) }
    }

    private func validateResponse(_ response: URLResponse?) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            return
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw CocoaError(
                .fileReadUnknown,
                userInfo: [NSLocalizedDescriptionKey: "The server returned status \(httpResponse.statusCode) while downloading the basemap package."]
            )
        }
    }

    private func destinationURL(for relativePath: String, inside rootDirectory: URL) throws -> URL {
        let normalizedPath = normalizedRelativePath(relativePath)
        guard !normalizedPath.isEmpty else {
            throw CocoaError(.fileWriteInvalidFileName, userInfo: [NSLocalizedDescriptionKey: "Basemap package contains an empty file path."])
        }

        let destinationURL = rootDirectory.appendingPathComponent(normalizedPath, isDirectory: false).standardizedFileURL
        guard destinationURL.path.hasPrefix(rootDirectory.standardizedFileURL.path) else {
            throw CocoaError(.fileWriteInvalidFileName, userInfo: [NSLocalizedDescriptionKey: "Basemap package contains an invalid file path."])
        }

        return destinationURL
    }

    private func normalizedRelativePath(_ path: String) -> String {
        path
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/")
            .filter { $0 != "." && $0 != ".." }
            .map(String.init)
            .joined(separator: "/")
    }

    private func loadMetadata(from packageDirectory: URL) -> InstalledPackageMetadata? {
        let metadataURL = packageDirectory.appendingPathComponent(Constants.metadataFilename)
        do {
            let data = try Data(contentsOf: metadataURL)
            return try JSONDecoder().decode(InstalledPackageMetadata.self, from: data)
        } catch {
            RediLogger.basemap.error("Failed to load basemap metadata at \(metadataURL.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    private func writeMetadata(_ metadata: InstalledPackageMetadata, inside packageDirectory: URL) throws {
        let metadataURL = packageDirectory.appendingPathComponent(Constants.metadataFilename)
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: metadataURL, options: .atomic)
    }

    private func activePackageID() -> String? {
        guard let contents = RediLogger.basemap.tryOrNil("Read active package ID", operation: {
            try String(contentsOf: activePackageFileURL, encoding: .utf8)
        }) else {
            return nil
        }
        let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func saveActivePackageID(_ packageID: String?) {
        do { try ensureManagedPackageRoot() } catch {
            RediLogger.basemap.error("Failed to create managed package root: \(error.localizedDescription)")
        }
        guard let packageID else {
            do { try fileManager.removeItem(at: activePackageFileURL) } catch {
                RediLogger.basemap.error("Failed to remove active package file: \(error.localizedDescription)")
            }
            return
        }
        do {
            try packageID.write(to: activePackageFileURL, atomically: true, encoding: .utf8)
            try excludeFromBackup(activePackageFileURL)
        } catch {
            RediLogger.basemap.error("Failed to save active package ID: \(error.localizedDescription)")
        }
    }

    private func ensureManagedPackageRoot() throws {
        try fileManager.createDirectory(at: managedPackageRoot, withIntermediateDirectories: true, attributes: nil)
        try excludeFromBackup(managedPackageRoot)
    }

    private func directoryInstalledDate(for directoryURL: URL) -> Date {
        let values = try? directoryURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return values?.creationDate ?? values?.contentModificationDate ?? .distantPast
    }

    private func directoryByteCount(at directoryURL: URL) -> Int64 {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]
        let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        )

        var total: Int64 = 0
        while let fileURL = enumerator?.nextObject() as? URL {
            guard let values = try? fileURL.resourceValues(forKeys: resourceKeys),
                  values.isRegularFile == true else {
                continue
            }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }

        return total
    }

    private func readableError(from error: Error) -> String {
        if let cocoaError = error as? CocoaError,
           let description = cocoaError.userInfo[NSLocalizedDescriptionKey] as? String {
            return description
        }
        return error.localizedDescription
    }

    private func excludeFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }

    private func isManagedPackageRoot(_ url: URL) -> Bool {
        url.standardizedFileURL.path == managedPackageRoot.standardizedFileURL.path
    }

    private static func managedPackageRoot(fileManager: FileManager) -> URL {
        let applicationSupportRoot = RediLogger.basemap.tryOrDefault(fileManager.temporaryDirectory, "Resolve app support directory") {
            try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }

        return applicationSupportRoot
            .appendingPathComponent("RediM8", isDirectory: true)
            .appendingPathComponent("OfflineBasemap", isDirectory: true)
    }

    private static func defaultSearchRoots(bundle: Bundle, fileManager: FileManager, managedPackageRoot: URL) -> [URL] {
        let workspaceRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)

        let candidates: [URL?] = [
            bundle.resourceURL?.appendingPathComponent("OfflineBasemap", isDirectory: true),
            bundle.bundleURL.appendingPathComponent("Resources", isDirectory: true).appendingPathComponent("OfflineBasemap", isDirectory: true),
            workspaceRoot.appendingPathComponent("RediM8", isDirectory: true).appendingPathComponent("Resources", isDirectory: true).appendingPathComponent("OfflineBasemap", isDirectory: true),
            Self.sourceTreeRoot().appendingPathComponent("Resources", isDirectory: true).appendingPathComponent("OfflineBasemap", isDirectory: true),
            managedPackageRoot
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

    private static func catalogSort(lhs: OfflineBasemapCatalogPackage, rhs: OfflineBasemapCatalogPackage) -> Bool {
        if lhs.availability.sortPriority != rhs.availability.sortPriority {
            return lhs.availability.sortPriority < rhs.availability.sortPriority
        }

        if lhs.isFeatured != rhs.isFeatured {
            return lhs.isFeatured && !rhs.isFeatured
        }

        return lhs.name < rhs.name
    }
}
