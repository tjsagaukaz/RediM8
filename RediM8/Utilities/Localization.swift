import Foundation

enum L10n {
    static func tr(_ key: String, _ fallback: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: .main, value: fallback, comment: "")
    }

    static func format(_ key: String, _ fallback: String, _ arguments: CVarArg...) -> String {
        String(format: tr(key, fallback), locale: .autoupdatingCurrent, arguments: arguments)
    }
}
