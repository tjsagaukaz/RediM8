import Foundation

enum HazardStorageKey {
    static let reports = "hazard_intelligence_reports"
    static let sensitiveReports = "hazard_intelligence_reports.sensitive.v1"
    static let sensitiveMigrationCompleted = "hazard_intelligence_reports.sensitive.migration.v1.complete"
}

final class SensitiveHazardReportService {
    private let secureStore: SecureStore

    init(secureStore: SecureStore) {
        self.secureStore = secureStore
    }

    func loadReports() throws -> [HazardIntelligenceService.HazardReport] {
        try secureStore.load([HazardIntelligenceService.HazardReport].self, for: HazardStorageKey.sensitiveReports) ?? []
    }

    func saveReports(_ reports: [HazardIntelligenceService.HazardReport]) throws {
        if reports.isEmpty {
            try secureStore.deleteValue(for: HazardStorageKey.sensitiveReports)
        } else {
            try secureStore.save(reports, for: HazardStorageKey.sensitiveReports)
        }
    }

    var hasStoredReports: Bool {
        secureStore.containsValue(for: HazardStorageKey.sensitiveReports)
    }
}

final class SensitiveHazardReportMigrationService {
    private let store: SQLiteStore
    private let sensitiveHazardReportService: SensitiveHazardReportService

    init(store: SQLiteStore, sensitiveHazardReportService: SensitiveHazardReportService) {
        self.store = store
        self.sensitiveHazardReportService = sensitiveHazardReportService
    }

    func runIfNeeded() throws {
        guard !(try isMigrationCompleted()) else {
            return
        }

        let legacyReports = try store.load([HazardIntelligenceService.HazardReport].self, for: HazardStorageKey.reports) ?? []
        guard !legacyReports.isEmpty else {
            try markMigrationCompleted()
            return
        }

        let standardReports = legacyReports.filter { !$0.requiresSecureStorage }
        let sensitiveReports = legacyReports.filter(\.requiresSecureStorage)

        if sensitiveHazardReportService.hasStoredReports {
            try store.save(standardReports, for: HazardStorageKey.reports)
            try markMigrationCompleted()
            return
        }

        try sensitiveHazardReportService.saveReports(sensitiveReports)
        try store.save(standardReports, for: HazardStorageKey.reports)
        try markMigrationCompleted()
    }

    func markMigrationCompleted() throws {
        try store.save(true, for: HazardStorageKey.sensitiveMigrationCompleted)
    }

    private func isMigrationCompleted() throws -> Bool {
        try store.load(Bool.self, for: HazardStorageKey.sensitiveMigrationCompleted) ?? false
    }
}
