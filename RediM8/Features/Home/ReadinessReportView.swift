import SwiftUI
import UIKit

struct ReadinessReportView: View {
    let report: ReadinessReport
    let onShare: () throws -> [Any]
    let onSavePDF: () throws -> URL
    let onSendToFamily: () throws -> [Any]

    @Environment(\.dismiss) private var dismiss
    @State private var shareSheetPayload: ShareSheetPayload?
    @State private var notice: ReportNotice?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard

                ReportCard(title: "Preparedness Breakdown", subtitle: "Core categories tracked offline") {
                    VStack(spacing: 14) {
                        ForEach(report.categoryScores) { score in
                            ReportProgressRow(title: score.category.title, value: score.score)
                        }
                    }
                }

                ReportCard(title: "Preparedness Highlights", subtitle: "Current supplies versus recommended targets") {
                    VStack(spacing: 12) {
                        ForEach(report.highlights) { highlight in
                            HighlightCard(highlight: highlight)
                        }
                    }
                }

                ReportCard(title: "Emergency Plan Summary", subtitle: "Meeting points, contacts and evacuation details") {
                    VStack(alignment: .leading, spacing: 16) {
                        ReportLineList(lines: report.planSummary.summaryLines)
                        ReportDetailBlock(title: "Meeting Points", lines: report.planSummary.meetingPoints, emptyState: "No meeting points saved")
                        ReportDetailBlock(title: "Emergency Contacts", lines: report.planSummary.emergencyContacts, emptyState: "No emergency contacts saved")
                        ReportDetailBlock(title: "Evacuation Routes", lines: report.planSummary.evacuationRoutes, emptyState: "No evacuation routes saved")
                    }
                }

                ReportCard(title: "Priority Actions", subtitle: "Highest-value improvements to lift readiness") {
                    if report.suggestions.isEmpty {
                        Text("No priority actions detected. Keep supplies current and review your emergency plan regularly.")
                            .font(.subheadline)
                            .foregroundStyle(Self.secondaryText)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(report.suggestions.prefix(5)).indices, id: \.self) { index in
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

                VStack(spacing: 12) {
                    Button("Share") {
                        handleAction(title: "Share Report", action: onShare)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Button("Save PDF") {
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
                    .buttonStyle(SecondaryActionButtonStyle())

                    Button("Send to Family") {
                        handleAction(title: "Send to Family", action: onSendToFamily)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
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
        .sheet(item: $shareSheetPayload) { payload in
            ActivityView(activityItems: payload.items)
        }
        .alert(item: $notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("OK")))
        }
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

    private func handleAction(title: String, action: () throws -> [Any]) {
        do {
            shareSheetPayload = ShareSheetPayload(title: title, items: try action())
        } catch {
            notice = ReportNotice(title: "\(title) Failed", message: error.localizedDescription)
        }
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
}

private struct ReportNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
