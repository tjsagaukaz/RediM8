import XCTest
@testable import RediM8

@MainActor
final class OfflineBasemapServiceTests: XCTestCase {
    func testUsesPremiumPackageWhenLocalStyleAndAssetsArePresent() throws {
        let sandboxURL = try makeSandboxDirectory()
        let packageURL = sandboxURL.appendingPathComponent("PremiumTactical", isDirectory: true)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)

        try writeText(
            """
            {
              "version": 8,
              "name": "RediM8 Premium Tactical",
              "sprite": "sprite/sprite",
              "glyphs": "fonts/{fontstack}/{range}.pbf",
              "sources": {
                "basemap": {
                  "type": "raster",
                  "tiles": ["tiles/{z}/{x}/{y}.png"],
                  "tileSize": 256
                }
              },
              "layers": [
                {
                  "id": "background",
                  "type": "background",
                  "paint": {
                    "background-color": "#000000"
                  }
                },
                {
                  "id": "basemap",
                  "type": "raster",
                  "source": "basemap"
                }
              ]
            }
            """,
            to: packageURL.appendingPathComponent("style.json")
        )

        try FileManager.default.createDirectory(at: packageURL.appendingPathComponent("tiles", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: packageURL.appendingPathComponent("fonts", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: packageURL.appendingPathComponent("sprite", isDirectory: true), withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: packageURL.appendingPathComponent("sprite/sprite.json"), options: .atomic)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: packageURL.appendingPathComponent("sprite/sprite.png"), options: .atomic)

        let fallbackStyleURL = try writeFallbackStyle(in: sandboxURL)
        let generatedStyleDirectory = sandboxURL.appendingPathComponent("generated", isDirectory: true)
        let service = OfflineBasemapService(
            bundle: .main,
            fileManager: .default,
            searchRoots: [sandboxURL],
            generatedStyleDirectory: generatedStyleDirectory,
            fallbackStyleURL: fallbackStyleURL
        )

        let configuration = service.configuration

        XCTAssertTrue(configuration.isPremiumActive)
        XCTAssertTrue(configuration.statusMessage.contains("Premium offline basemap active"))
        XCTAssertNotEqual(configuration.styleURL, fallbackStyleURL)

        let rewrittenStyleData = try Data(contentsOf: configuration.styleURL)
        let rewrittenStyle = try XCTUnwrap(try JSONSerialization.jsonObject(with: rewrittenStyleData) as? [String: Any])
        XCTAssertEqual(rewrittenStyle["name"] as? String, "RediM8 Premium Tactical")

        let spritePath = try XCTUnwrap(rewrittenStyle["sprite"] as? String)
        XCTAssertTrue(spritePath.hasPrefix("file://"))

        let sources = try XCTUnwrap(rewrittenStyle["sources"] as? [String: Any])
        let basemap = try XCTUnwrap(sources["basemap"] as? [String: Any])
        let tiles = try XCTUnwrap(basemap["tiles"] as? [String])
        XCTAssertEqual(tiles.count, 1)
        XCTAssertTrue(tiles[0].hasPrefix("file://"))
        XCTAssertTrue(tiles[0].contains("{z}"))
    }

    func testFallsBackWhenPremiumPackageIsMissingSpriteAssets() throws {
        let sandboxURL = try makeSandboxDirectory()
        let packageURL = sandboxURL.appendingPathComponent("BrokenPremiumPackage", isDirectory: true)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)

        try writeText(
            """
            {
              "version": 8,
              "name": "Broken Package",
              "sprite": "sprite/sprite",
              "sources": {},
              "layers": []
            }
            """,
            to: packageURL.appendingPathComponent("style.json")
        )

        let fallbackStyleURL = try writeFallbackStyle(in: sandboxURL)
        let service = OfflineBasemapService(
            bundle: .main,
            fileManager: .default,
            searchRoots: [sandboxURL],
            generatedStyleDirectory: sandboxURL.appendingPathComponent("generated", isDirectory: true),
            fallbackStyleURL: fallbackStyleURL
        )

        let configuration = service.configuration

        XCTAssertFalse(configuration.isPremiumActive)
        XCTAssertEqual(configuration.styleURL, fallbackStyleURL)
        XCTAssertTrue(configuration.statusMessage.contains("unavailable"))
        XCTAssertTrue(configuration.statusMessage.contains("incomplete or invalid"))
    }

    private func makeSandboxDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }

    private func writeFallbackStyle(in directory: URL) throws -> URL {
        let fallbackURL = directory.appendingPathComponent("fallback-style.json")
        try writeText(
            """
            {
              "version": 8,
              "name": "Fallback",
              "sources": {},
              "layers": [
                {
                  "id": "background",
                  "type": "background",
                  "paint": {
                    "background-color": "#020805"
                  }
                }
              ]
            }
            """,
            to: fallbackURL
        )
        return fallbackURL
    }

    private func writeText(_ text: String, to url: URL) throws {
        try Data(text.utf8).write(to: url, options: .atomic)
    }
}
