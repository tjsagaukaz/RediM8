import Foundation

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }

    var roundedIntString: String {
        String(Int(self.rounded()))
    }
}

extension Int {
    var percentageText: String {
        "\(self)%"
    }
}

extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

extension JSONEncoder {
    static let rediM8: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    static let rediM8: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension Bundle {
    func decode<T: Decodable>(_ filename: String, as type: T.Type) throws -> T {
        let directURL = url(forResource: filename, withExtension: nil)
        let dataFolderURL = url(forResource: filename, withExtension: nil, subdirectory: "Data")
        let bundleDataURL = bundleURL.appendingPathComponent("Data", isDirectory: true).appendingPathComponent(filename)
        let workspaceDataURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("RediM8", isDirectory: true)
            .appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent(filename)
        let sourceTreeDataURL = URL(fileURLWithPath: #filePath, isDirectory: false)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent(filename)

        let candidateURLs = [directURL, dataFolderURL, bundleDataURL, workspaceDataURL, sourceTreeDataURL]
        let resolvedURL = candidateURLs.first { url in
            guard let url else {
                return false
            }

            return FileManager.default.fileExists(atPath: url.path)
        } ?? nil

        guard let url = resolvedURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder.rediM8.decode(type, from: data)
    }
}


extension DateFormatter {
    static let rediM8Short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let rediM8MonthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
}

extension RelativeDateTimeFormatter {
    static let rediM8Short: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}

extension Date {
    func rediM8FreshnessLabel(reference: Date = .now) -> String {
        let absoluteDate = DateFormatter.rediM8Short.string(from: self)
        let delta = timeIntervalSince(reference)

        if delta > 300 {
            return "Dated \(absoluteDate)"
        }

        if abs(delta) < 90 {
            return "Updated just now"
        }

        if abs(delta) < 86_400 {
            let relativeDate = RelativeDateTimeFormatter.rediM8Short.localizedString(for: self, relativeTo: reference)
            return "Updated \(relativeDate)"
        }

        return "Updated \(absoluteDate)"
    }
}
