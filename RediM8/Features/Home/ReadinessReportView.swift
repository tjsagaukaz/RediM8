import SwiftUI
import UIKit

struct ReadinessReportView: View {
    let report: ReadinessReport
    let isProUser: Bool
    let onShare: () throws -> [Any]
    let onSavePDF: () throws -> URL
    let onSendToFamily: () throws -> [Any]

    @Environment(\.dismiss) private var dismiss
    @State private var shareSheetPayload: ShareSheetPayload?
    @State private var notice: ReportNotice?
    @State private var isShowingBreakdown = false
    @State private var isShowingHighlights = false
    @State private var isShowingPlanSummary = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                SystemStatusRail(items: reportStatusItems, accent: Self.highlight)
                reportActionCard
                executiveSummaryCard
                priorityActionsCard

                if isProUser {
                    CollapsiblePanelCard(
                        title: "Preparedness Breakdown",
                        subtitle: "Full category scores tracked offline.",
                        accent: Self.highlight,
                        isExpanded: $isShowingBreakdown
                    ) {
                        VStack(spacing: 14) {
                            ForEach(report.categoryScores) { score in
                                ReportProgressRow(title: score.category.title, value: score.score)
                            }
                        }
                    }

                    CollapsiblePanelCard(
                        title: "Household Targets",
                        subtitle: "Current supplies versus recommended targets.",
                        accent: ColorTheme.info,
                        isExpanded: $isShowingHighlights
                    ) {
                        VStack(spacing: 12) {
                            ForEach(report.highlights) { highlight in
                                HighlightCard(highlight: highlight)
                            }
                        }
                    }
                }

                CollapsiblePanelCard(
                    title: "Emergency Plan Detail",
                    subtitle: "Meeting points, contacts, and evacuation coverage.",
                    accent: ColorTheme.textTertiary,
                    isExpanded: $isShowingPlanSummary
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        ReportLineList(lines: report.planSummary.summaryLines)
                        ReportDetailBlock(title: "Meeting Points", lines: report.planSummary.meetingPoints, emptyState: "No meeting points saved")
                        ReportDetailBlock(title: "Emergency Contacts", lines: report.planSummary.emergencyContacts, emptyState: "No emergency contacts saved")
                        ReportDetailBlock(title: "Evacuation Routes", lines: report.planSummary.evacuationRoutes, emptyState: "No evacuation routes saved")
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Readiness Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .background(Self.background.ignoresSafeArea())
        .sheet(item: $shareSheetPayload, onDismiss: {
            dismissShareSheet()
        }) { payload in
            ActivityView(activityItems: payload.items) {
                dismissShareSheet()
            }
        }
        .alert(item: $notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("OK")))
        }
    }

    private var reportStatusItems: [OperationalStatusItem] {
        [
            OperationalStatusItem(
                iconName: "shield",
                label: "Tier",
                value: report.tier.displayTitle,
                tone: report.overallScore >= 75 ? .ready : .caution
            ),
            OperationalStatusItem(
                iconName: "warning",
                label: "Actions",
                value: "\(report.suggestions.count)",
                tone: report.suggestions.isEmpty ? .ready : .caution
            ),
            OperationalStatusItem(
                iconName: "family",
                label: "Contacts",
                value: "\(report.planSummary.emergencyContacts.count)",
                tone: report.planSummary.emergencyContacts.isEmpty ? .neutral : .info
            ),
            OperationalStatusItem(
                iconName: "map_marker",
                label: "Routes",
                value: "\(report.planSummary.evacuationRoutes.count)",
                tone: report.planSummary.evacuationRoutes.isEmpty ? .neutral : .info
            )
        ]
    }

    private var headerCard: some View {
        ReportCard(
            backgroundAssetName: "marketing_command_table",
            backgroundImageOffset: CGSize(width: 0, height: 0)
        ) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(report.title)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(ColorTheme.text)
                    Text("Generated \(DateFormatter.rediM8Short.string(from: report.generatedAt))")
                        .font(.subheadline)
                        .foregroundStyle(Self.secondaryText)
                }

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Overall Score")
                            .font(.headline)
                            .foregroundStyle(Self.secondaryText)
                        Text(report.scoreSummary)
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Self.highlight)
                    }
                    Spacer()
                    StatusBadge(tier: report.tier)
                }

                VStack(alignment: .leading, spacing: 10) {
                    reportMetaRow(title: "Household", value: report.householdSummary)
                    reportMetaRow(title: "Scenarios", value: report.focusAreas.isEmpty ? "General Emergency" : report.focusAreas.joined(separator: ", "))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Focus Areas")
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    FlexibleTagLayout(tags: report.focusAreas.isEmpty ? ["General Emergency"] : report.focusAreas)
                }
            }
        }
    }

    private var reportActionCard: some View {
        ReportCard(title: "Share & Save", subtitle: "Brief the household now, or export a local PDF snapshot.") {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    reportPrimaryActionButton(title: "Share", action: {
                        handleAction(title: "Share Report", action: onShare)
                    })
                    reportSecondaryActionButton(title: "Save PDF", action: savePDF)
                    if isProUser {
                        reportSecondaryActionButton(title: "Send to Family", action: {
                            handleAction(title: "Send to Family", action: onSendToFamily)
                        })
                    }
                }

                VStack(spacing: 12) {
                    reportPrimaryActionButton(title: "Share", action: {
                        handleAction(title: "Share Report", action: onShare)
                    })
                    reportSecondaryActionButton(title: "Save PDF", action: savePDF)
                    if isProUser {
                        reportSecondaryActionButton(title: "Send to Family", action: {
                            handleAction(title: "Send to Family", action: onSendToFamily)
                        })
                    }
                }
            }
        }
    }

    private var executiveSummaryCard: some View {
        ReportCard(title: "Executive Summary", subtitle: "Strongest coverage, biggest gaps, and the next milestone before you dive into the full report.") {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    reportMetricTile(
                        title: "Overall",
                        value: "\(report.overallScore)%",
                        detail: report.tier.displayTitle,
                        tint: Self.highlight
                    )
                    reportMetricTile(
                        title: "Next Milestone",
                        value: nextMilestoneValue,
                        detail: nextMilestoneSummary,
                        tint: ColorTheme.warning
                    )
                    reportMetricTile(
                        title: "Focus",
                        value: report.focusAreas.isEmpty ? "General" : "\(report.focusAreas.count)",
                        detail: report.focusAreas.isEmpty ? "General emergency plan" : report.focusAreas.joined(separator: ", "),
                        tint: ColorTheme.info
                    )
                    reportMetricTile(
                        title: "Plan Coverage",
                        value: "\(report.planSummary.meetingPoints.count + report.planSummary.evacuationRoutes.count)",
                        detail: "\(report.planSummary.meetingPoints.count) meeting points, \(report.planSummary.evacuationRoutes.count) routes",
                        tint: ColorTheme.ready
                    )
                }

                executiveSummaryBlock(
                    title: "Strongest Coverage",
                    entries: strongestCoverageLines,
                    tint: Self.highlight
                )

                executiveSummaryBlock(
                    title: "Needs Attention",
                    entries: biggestGapLines,
                    tint: ColorTheme.warning
                )
            }
        }
    }

    private var priorityActionsCard: some View {
        ReportCard(title: "Top Actions", subtitle: "Highest-value improvements to lift readiness first.") {
            if report.suggestions.isEmpty {
                Text("No priority actions detected. Keep supplies current and review your emergency plan regularly.")
                    .font(.subheadline)
                    .foregroundStyle(Self.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(report.suggestions.prefix(3)).indices, id: \.self) { index in
                        let suggestion = report.suggestions[index]
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Self.highlight)
                                .frame(width: 22, alignment: .leading)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(suggestion.title)
                                    .font(.headline)
                                    .foregroundStyle(ColorTheme.text)
                                Text(suggestion.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(Self.secondaryText)
                            }
                        }
                    }
                }
            }
        }
    }

    private func reportMetaRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Self.secondaryText)
                .frame(width: 88, alignment: .leading)
            Text(value.isEmpty ? "Not set" : value)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var nextMilestoneValue: String {
        report.tier.nextDisplayTitle ?? "Complete"
    }

    private var nextMilestoneSummary: String {
        guard let target = report.tier.nextTarget, let title = report.tier.nextDisplayTitle else {
            return "All readiness milestones complete."
        }

        return "\(max(target - report.overallScore, 0))% to \(title)"
    }

    private var strongestCoverageLines: [String] {
        let scores = report.categoryScores.sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            return lhs.category.title < rhs.category.title
        }

        return Array(scores.prefix(2)).map { score in
            "\(score.category.title) is currently at \(score.score)%."
        }
    }

    private var biggestGapLines: [String] {
        if !report.suggestions.isEmpty {
            return Array(report.suggestions.prefix(2)).map { suggestion in
                "\(suggestion.title) (+\(suggestion.impact)% potential lift)."
            }
        }

        let scores = report.categoryScores.sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score < rhs.score
            }
            return lhs.category.title < rhs.category.title
        }

        return Array(scores.prefix(2)).map { score in
            "\(score.category.title) is still only at \(score.score)%."
        }
    }

    private func reportPrimaryActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(PrimaryActionButtonStyle())
    }

    private func reportSecondaryActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(SecondaryActionButtonStyle())
    }

    private func reportMetricTile(title: String, value: String, detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(RediTypography.metadata)
                .foregroundStyle(Self.secondaryText)

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(ColorTheme.text)

            Text(detail)
                .font(.caption)
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        )
    }

    private func executiveSummaryBlock(title: String, entries: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(ColorTheme.text)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(entries, id: \.self) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(tint)
                            .frame(width: 7, height: 7)
                            .padding(.top, 6)
                        Text(entry)
                            .font(.subheadline)
                            .foregroundStyle(Self.secondaryText)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        )
    }

    private func handleAction(title: String, action: () throws -> [Any]) {
        do {
            let items = try action()
            shareSheetPayload = ShareSheetPayload(
                title: title,
                items: items,
                cleanupURLs: items.compactMap { item in
                    guard let url = item as? URL else { return nil }
                    let temporaryDirectory = FileManager.default.temporaryDirectory.standardizedFileURL
                    let standardizedURL = url.standardizedFileURL
                    return standardizedURL.path.hasPrefix(temporaryDirectory.path) ? standardizedURL : nil
                }
            )
        } catch {
            notice = ReportNotice(title: "\(title) Failed", message: error.localizedDescription)
        }
    }

    private func savePDF() {
        do {
            let url = try onSavePDF()
            notice = ReportNotice(
                title: "PDF Saved",
                message: "Saved \(url.lastPathComponent) to the app's Readiness Reports folder."
            )
        } catch {
            notice = ReportNotice(
                title: "Save Failed",
                message: error.localizedDescription
            )
        }
    }

    private func dismissShareSheet() {
        guard let shareSheetPayload else { return }
        shareSheetPayload.cleanupURLs.forEach { try? FileManager.default.removeItem(at: $0) }
        self.shareSheetPayload = nil
    }

    fileprivate static let background = Color.black
    fileprivate static let cardBackground = Color(red: 0.08, green: 0.08, blue: 0.08)
    fileprivate static let cardBorder = Color.white.opacity(0.08)
    fileprivate static let secondaryText = Color.white.opacity(0.72)
    fileprivate static let highlight = Color(red: 0.22, green: 0.82, blue: 0.43)
}

private struct ReportCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let backgroundAssetName: String?
    let backgroundImageOffset: CGSize
    private let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        backgroundAssetName: String? = nil,
        backgroundImageOffset: CGSize = .zero,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.backgroundAssetName = backgroundAssetName
        self.backgroundImageOffset = backgroundImageOffset
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(ReadinessReportView.secondaryText)
                    }
                }
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ReadinessReportView.cardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var cardBackgroundView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(ReadinessReportView.cardBackground)

            if let backgroundAssetName {
                GeometryReader { proxy in
                    Image(backgroundAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(1.04)
                        .offset(backgroundImageOffset)
                        .saturation(0.88)
                        .contrast(1.04)
                        .brightness(-0.05)
                        .overlay {
                            ZStack {
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.34),
                                        Color.black.opacity(0.52),
                                        Color.black.opacity(0.76)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )

                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.54),
                                        Color.black.opacity(0.16),
                                        Color.black.opacity(0.42)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )

                                RadialGradient(
                                    colors: [
                                        Color.clear,
                                        Color.black.opacity(0.14),
                                        Color.black.opacity(0.32)
                                    ],
                                    center: .center,
                                    startRadius: 28,
                                    endRadius: max(proxy.size.width, proxy.size.height)
                                )
                            }
                        }
                        .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }
}

private struct ReportProgressRow: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ColorTheme.text)
                Spacer()
                Text("\(value)%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ReadinessReportView.highlight)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(ReadinessReportView.highlight)
                        .frame(width: max(proxy.size.width * CGFloat(value) / 100, 10))
                }
            }
            .frame(height: 10)
        }
    }
}

private struct HighlightCard: View {
    let highlight: ReadinessReportHighlight

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(highlight.title)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    Text(highlight.currentValue)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(ReadinessReportView.highlight)
                }
                Spacer()
                Text(highlight.recommendedValue)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ReadinessReportView.secondaryText)
                    .multilineTextAlignment(.trailing)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(ReadinessReportView.highlight)
                        .frame(width: max(proxy.size.width * CGFloat(highlight.progress.clamped(to: 0...1)), 12))
                }
            }
            .frame(height: 10)

            ReportLineList(lines: highlight.statusLines)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct ReportDetailBlock: View {
    let title: String
    let lines: [String]
    let emptyState: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ColorTheme.text)

            ReportLineList(lines: lines.isEmpty ? [emptyState] : lines)
        }
    }
}

private struct ReportLineList: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(ReadinessReportView.highlight)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(ReadinessReportView.secondaryText)
                }
            }
        }
    }
}

private struct FlexibleTagLayout: View {
    let tags: [String]

    var body: some View {
        ViewThatFits(in: .vertical) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    tagView(tag)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    tagView(tag)
                }
            }
        }
    }

    private func tagView(_ tag: String) -> some View {
        Text(tag)
            .font(.caption.weight(.semibold))
            .foregroundStyle(ReadinessReportView.highlight)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(ReadinessReportView.highlight.opacity(0.14), in: Capsule())
    }
}

private struct ShareSheetPayload: Identifiable {
    let id = UUID()
    let title: String
    let items: [Any]
    let cleanupURLs: [URL]
}

private struct ReportNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
