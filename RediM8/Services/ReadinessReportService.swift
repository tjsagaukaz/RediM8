import Foundation
import PDFKit
import UIKit

struct ReadinessReportHighlight: Identifiable, Equatable {
    let id: String
    let title: String
    let currentValue: String
    let recommendedValue: String
    let statusLines: [String]
    let progress: Double
}

struct ReadinessReportPlanSummary: Equatable {
    let summaryLines: [String]
    let meetingPoints: [String]
    let emergencyContacts: [String]
    let evacuationRoutes: [String]
}

struct ReadinessReport: Equatable {
    let title: String
    let generatedAt: Date
    let householdSize: Int
    let petCount: Int
    let overallScore: Int
    let tier: PrepTier
    let focusAreas: [String]
    let categoryScores: [CategoryScore]
    let highlights: [ReadinessReportHighlight]
    let planSummary: ReadinessReportPlanSummary
    let suggestions: [ImprovementSuggestion]

    var householdSummary: String {
        let people = householdSize == 1 ? "1 person" : "\(householdSize) people"
        guard petCount > 0 else {
            return people
        }

        let pets = petCount == 1 ? "1 pet" : "\(petCount) pets"
        return "\(people), \(pets)"
    }

    var scoreSummary: String {
        "\(overallScore)% \(tier.rawValue)"
    }

    var fileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "RediM8-Readiness-\(formatter.string(from: generatedAt)).pdf"
    }
}

final class ReadinessReportService {
    private let prepService: PrepService
    private let scenarioEngine: ScenarioEngine
    private let emergencyPlanService: EmergencyPlanService
    private let goBagService: GoBagService

    init(prepService: PrepService, scenarioEngine: ScenarioEngine, emergencyPlanService: EmergencyPlanService, goBagService: GoBagService) {
        self.prepService = prepService
        self.scenarioEngine = scenarioEngine
        self.emergencyPlanService = emergencyPlanService
        self.goBagService = goBagService
    }

    @MainActor
    func generateReport(profile: UserProfile, prepScore: PrepScore) -> ReadinessReport {
        let scenarios = scenarioEngine.selectedScenarios(for: profile.selectedScenarios)
        let targets = prepService.recommendedTargets(for: profile, scenarios: scenarios)
        let emergencyPlan = emergencyPlanService.generatePlan(for: profile)
        let goBagPlan = goBagService.plan(for: profile)
        let completedChecklist = emergencyPlanService.loadCompletedChecklistItemIDs()
        let categoryScores = prepScore.categoryScores
        let scoreIndex = Dictionary(uniqueKeysWithValues: categoryScores.map { ($0.category, $0.score) })

        let backupLightingReady = profile.checklistState(for: .torch)
        let powerBankReady = profile.checklistState(for: .powerBank)
        let radioReady = profile.checklistState(for: .batteryRadio)
        let firstAidReady = profile.checklistState(for: .firstAidKit)
        let fireBlanketReady = profile.checklistState(for: .fireBlanket)
        let totalChecklistItems = emergencyPlan.checklists.flatMap(\.items).count
        let bushfireSummaryLines = profile.isBushfireModeEnabled
            ? [
                "Bushfire checklist: \(profile.bushfireReadiness.checklist.filter(\.isChecked).count)/\(profile.bushfireReadiness.checklist.count) complete",
                "Property prep: \(profile.bushfireReadiness.propertyItems.filter(\.isChecked).count)/\(profile.bushfireReadiness.propertyItems.count) complete"
            ]
            : []

        return ReadinessReport(
            title: "RediM8 Household Readiness",
            generatedAt: .now,
            householdSize: profile.household.totalPeople,
            petCount: profile.household.petCount,
            overallScore: prepScore.overall,
            tier: prepScore.tier,
            focusAreas: scenarios.map(\.name),
            categoryScores: categoryScores,
            highlights: [
                ReadinessReportHighlight(
                    id: "water",
                    title: "Water",
                    currentValue: "\(profile.supplies.waterLitres.roundedIntString)L stored",
                    recommendedValue: "Recommended: \(targets.waterLitres.roundedIntString)L",
                    statusLines: [
                        profile.supplies.waterLitres >= targets.waterLitres
                            ? "Household water target met."
                            : "Add \((targets.waterLitres - profile.supplies.waterLitres).clamped(to: 0...10_000).roundedIntString)L to close the gap."
                    ],
                    progress: Double(scoreIndex[.water] ?? 0) / 100
                ),
                ReadinessReportHighlight(
                    id: "food",
                    title: "Food",
                    currentValue: "\(profile.supplies.foodDays.roundedIntString) days supply",
                    recommendedValue: "Recommended: \(targets.foodDays.roundedIntString) days",
                    statusLines: [
                        profile.supplies.foodDays >= targets.foodDays
                            ? "Shelf-stable food target met."
                            : "Add \((targets.foodDays - profile.supplies.foodDays).clamped(to: 0...100).roundedIntString) more days of ready food."
                    ],
                    progress: Double(scoreIndex[.food] ?? 0) / 100
                ),
                ReadinessReportHighlight(
                    id: "medical",
                    title: "Medical",
                    currentValue: firstAidReady ? "First aid kit available" : "First aid kit missing",
                    recommendedValue: "Emergency contacts: \(profile.emergencyContacts.count)",
                    statusLines: [
                        fireBlanketReady ? "Fire blanket available." : "Fire blanket still needed.",
                        profile.medicalNotes.nilIfBlank == nil ? "No household medical note summary saved." : "Household medical notes saved."
                    ],
                    progress: Double(scoreIndex[.medical] ?? 0) / 100
                ),
                ReadinessReportHighlight(
                    id: "power",
                    title: "Power",
                    currentValue: backupLightingReady ? "Backup lighting available" : "Backup lighting incomplete",
                    recommendedValue: "Battery reserve: \(profile.supplies.batteryCapacity.roundedIntString)%",
                    statusLines: [
                        powerBankReady ? "Power bank available." : "Power bank still needed.",
                        radioReady ? "Battery radio available." : "Battery radio not detected."
                    ],
                    progress: Double(scoreIndex[.power] ?? 0) / 100
                )
            ],
            planSummary: ReadinessReportPlanSummary(
                summaryLines: [
                    "72-hour water target: \(emergencyPlan.waterRequiredLitres.roundedIntString)L",
                    "72-hour food target: \(emergencyPlan.foodRequiredCalories) calories",
                    "Checklist progress: \(completedChecklist.count)/\(totalChecklistItems) complete",
                    "Go bag readiness: \(goBagPlan.readiness.completedCount)/\(goBagPlan.readiness.totalCount) items packed"
                ] + bushfireSummaryLines,
                meetingPoints: [profile.meetingPoints.primary, profile.meetingPoints.secondary, profile.meetingPoints.fallback]
                    .compactMap(\.nilIfBlank),
                emergencyContacts: profile.emergencyContacts
                    .map { [$0.name.nilIfBlank, $0.phone.nilIfBlank].compactMap { $0 }.joined(separator: " · ") }
                    .filter { !$0.isEmpty },
                evacuationRoutes: profile.evacuationRoutes.compactMap(\.nilIfBlank)
            ),
            suggestions: prepScore.suggestions
        )
    }

    func exportPDF(for report: ReadinessReport) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        try pdfData(for: report).write(to: url, options: .atomic)
        return url
    }

    func savePDF(for report: ReadinessReport) throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = documents.appendingPathComponent("Readiness Reports", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
        let url = folder.appendingPathComponent(report.fileName)
        try pdfData(for: report).write(to: url, options: .atomic)
        return url
    }

    func familyShareMessage(for report: ReadinessReport) -> String {
        let focusAreas = report.focusAreas.isEmpty ? "General Emergency" : report.focusAreas.joined(separator: ", ")
        let topActions = report.suggestions.prefix(3).map(\.title).joined(separator: ", ")
        return """
        RediM8 Household Readiness

        Overall score: \(report.scoreSummary)
        Household: \(report.householdSummary)
        Focus areas: \(focusAreas)
        Next improvements: \(topActions)
        """
    }

    private func pdfData(for report: ReadinessReport) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let rawData = renderer.pdfData { context in
            let theme = PDFTheme()
            var y = PDFLayout.margin

            func beginPage() {
                context.beginPage()
                theme.background.setFill()
                context.cgContext.fill(pageRect)
                y = PDFLayout.margin
            }

            func ensureSpace(_ height: CGFloat) {
                if y + height > pageRect.height - PDFLayout.margin {
                    beginPage()
                }
            }

            func drawText(_ text: String, font: UIFont, color: UIColor, x: CGFloat, width: CGFloat) -> CGFloat {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                let rect = NSString(string: text).boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )
                NSString(string: text).draw(
                    with: CGRect(x: x, y: y, width: width, height: ceil(rect.height)),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )
                return ceil(rect.height)
            }

            func drawCard(title: String, lines: [String], height: CGFloat? = nil) {
                let estimatedHeight = height ?? CGFloat(54 + lines.count * 20)
                ensureSpace(estimatedHeight + 12)
                let rect = CGRect(x: PDFLayout.margin, y: y, width: pageRect.width - PDFLayout.margin * 2, height: estimatedHeight)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 18)
                theme.panel.setFill()
                path.fill()
                theme.border.setStroke()
                path.lineWidth = 1
                path.stroke()

                let innerX = rect.minX + 16
                y += 14
                _ = drawText(title, font: theme.sectionTitleFont, color: theme.text, x: innerX, width: rect.width - 32)
                y += 24
                for line in lines {
                    let lineHeight = drawText(line, font: theme.bodyFont, color: theme.secondaryText, x: innerX, width: rect.width - 32)
                    y += lineHeight + 6
                }
                y = rect.maxY + 12
            }

            func drawBar(label: String, value: Int) {
                ensureSpace(42)
                let x = PDFLayout.margin
                let width = pageRect.width - PDFLayout.margin * 2
                _ = drawText(label, font: theme.bodyBoldFont, color: theme.text, x: x, width: width - 60)
                _ = drawText("\(value)%", font: theme.bodyBoldFont, color: theme.highlight, x: x + width - 60, width: 60)
                y += 20
                let barRect = CGRect(x: x, y: y, width: width, height: 10)
                let track = UIBezierPath(roundedRect: barRect, cornerRadius: 5)
                theme.track.setFill()
                track.fill()
                let fillRect = CGRect(x: x, y: y, width: max(width * CGFloat(value) / 100, 12), height: 10)
                let fill = UIBezierPath(roundedRect: fillRect, cornerRadius: 5)
                theme.highlight.setFill()
                fill.fill()
                y += 22
            }

            beginPage()

            let titleHeight = drawText(report.title, font: theme.titleFont, color: theme.text, x: PDFLayout.margin, width: pageRect.width - PDFLayout.margin * 2)
            y += titleHeight + 8
            let subtitle = "\(report.scoreSummary) • \(report.householdSummary)"
            let subtitleHeight = drawText(subtitle, font: theme.subtitleFont, color: theme.highlight, x: PDFLayout.margin, width: pageRect.width - PDFLayout.margin * 2)
            y += subtitleHeight + 8
            let generatedLine = "Generated \(DateFormatter.rediM8Short.string(from: report.generatedAt))"
            let generatedHeight = drawText(generatedLine, font: theme.bodyFont, color: theme.secondaryText, x: PDFLayout.margin, width: pageRect.width - PDFLayout.margin * 2)
            y += generatedHeight + 18

            drawCard(
                title: "Household Overview",
                lines: [
                    "Household: \(report.householdSummary)",
                    "Focus areas: \(report.focusAreas.isEmpty ? "General Emergency" : report.focusAreas.joined(separator: ", "))"
                ],
                height: 90
            )

            ensureSpace(24)
            _ = drawText("Preparedness Breakdown", font: theme.sectionTitleFont, color: theme.text, x: PDFLayout.margin, width: pageRect.width - PDFLayout.margin * 2)
            y += 28
            for score in report.categoryScores {
                drawBar(label: score.category.title, value: score.score)
            }

            for highlight in report.highlights {
                var lines = [
                    highlight.currentValue,
                    highlight.recommendedValue
                ]
                lines.append(contentsOf: highlight.statusLines)
                drawCard(title: highlight.title, lines: lines, height: CGFloat(58 + lines.count * 18))
            }

            drawCard(title: "Emergency Plan Summary", lines: report.planSummary.summaryLines + [
                "Meeting points: \(report.planSummary.meetingPoints.isEmpty ? "Not set" : report.planSummary.meetingPoints.joined(separator: " | "))",
                "Emergency contacts: \(report.planSummary.emergencyContacts.isEmpty ? "None saved" : report.planSummary.emergencyContacts.joined(separator: " | "))",
                "Evacuation routes: \(report.planSummary.evacuationRoutes.isEmpty ? "No routes saved" : report.planSummary.evacuationRoutes.joined(separator: " | "))"
            ], height: 152)

            drawCard(
                title: "Priority Actions",
                lines: report.suggestions.map { "\($0.title) — \($0.detail)" },
                height: CGFloat(54 + max(report.suggestions.count, 1) * 28)
            )
        }

        guard let document = PDFDocument(data: rawData) else {
            return rawData
        }

        document.documentAttributes = [
            PDFDocumentAttribute.titleAttribute: report.title,
            PDFDocumentAttribute.authorAttribute: "RediM8"
        ]
        return document.dataRepresentation() ?? rawData
    }
}

private enum PDFLayout {
    static let margin: CGFloat = 28
}

private struct PDFTheme {
    let background = UIColor.black
    let panel = UIColor(white: 0.10, alpha: 1)
    let border = UIColor(white: 0.18, alpha: 1)
    let track = UIColor(white: 0.18, alpha: 1)
    let text = UIColor.white
    let secondaryText = UIColor(white: 0.78, alpha: 1)
    let highlight = UIColor(red: 0.22, green: 0.82, blue: 0.43, alpha: 1)

    let titleFont = UIFont.systemFont(ofSize: 26, weight: .bold)
    let subtitleFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
    let sectionTitleFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
    let bodyFont = UIFont.systemFont(ofSize: 12, weight: .regular)
    let bodyBoldFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
}
