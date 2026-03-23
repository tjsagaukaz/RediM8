import SwiftUI

struct DiagnosticsView: View {
    @State private var events: [DiagnosticEvent] = []
    @State private var isExporting = false
    @State private var exportData: Data?

    private let store = DiagnosticStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                diagnosticsHero
                statusSummaryCard
                eventListCard
            }
            .padding(20)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { events = store.recentEvents(limit: 50) }
        .sheet(isPresented: $isExporting) {
            if let exportData {
                ShareSheet(activityItems: [exportData])
            }
        }
    }

    // MARK: - Hero

    private var diagnosticsHero: some View {
        ModeHeroCard(
            eyebrow: "Advanced",
            title: "Local Diagnostics",
            subtitle: "All diagnostic data is stored locally on this device. Nothing is sent externally.",
            iconName: "waveform.path.ecg",
            accent: ColorTheme.textTertiary
        ) {
            TrustPillGroup(items: [
                TrustPillItem(title: "Fully offline", tone: .verified),
                TrustPillItem(title: "No PII collected", tone: .info),
                TrustPillItem(title: "\(store.eventCount) events", tone: .caution)
            ])
        }
    }

    // MARK: - Status Summary

    private var statusSummaryCard: some View {
        let crashes = events.filter { $0.type == .crash }.count
        let errors = events.filter { $0.type == .error }.count
        let degraded = events.filter { $0.type == .degraded }.count
        let recoveries = events.filter { $0.type == .recovery }.count

        let statusText: String
        let statusTone: OperationalStatusTone
        if crashes == 0, errors == 0 {
            statusText = "System Healthy"
            statusTone = .ready
        } else if crashes > 0 {
            statusText = "Degraded: \(crashes) crash(es) detected"
            statusTone = .danger
        } else {
            statusText = "Degraded: \(errors) error(s)"
            statusTone = .caution
        }

        return PanelCard(
            title: "System Status",
            subtitle: statusText
        ) {
            VStack(alignment: .leading, spacing: 8) {
                statusRow(label: "Crashes", count: crashes, tone: .danger)
                statusRow(label: "Errors", count: errors, tone: .caution)
                statusRow(label: "Degraded", count: degraded, tone: .caution)
                statusRow(label: "Recoveries", count: recoveries, tone: .ready)
            }

            SettingsDivider()

            Button {
                exportData = store.exportJSON()
                isExporting = exportData != nil
            } label: {
                SettingsActionRow(
                    title: "Export Diagnostics",
                    subtitle: "Share a JSON report of recent diagnostic events",
                    value: "Export",
                    tint: ColorTheme.textTertiary
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Event List

    private var eventListCard: some View {
        PanelCard(
            title: "Recent Events",
            subtitle: events.isEmpty ? "No diagnostic events recorded" : "Showing up to 50 most recent"
        ) {
            if events.isEmpty {
                Text("No events yet. The system is operating normally.")
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textSecondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(events) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                eventTypeBadge(event.type)
                                Spacer()
                                Text(event.timestampText)
                                    .font(RediTypography.caption)
                                    .foregroundStyle(ColorTheme.textTertiary)
                            }

                            if let error = event.error {
                                Text(error)
                                    .font(RediTypography.body)
                                    .foregroundStyle(ColorTheme.text)
                                    .lineLimit(2)
                            }

                            if let service = event.context["service"] {
                                Text(service.uppercased())
                                    .font(RediTypography.label)
                                    .tracking(1.0)
                                    .foregroundStyle(ColorTheme.textTertiary)
                            }
                        }
                        .padding(.vertical, 8)

                        if event.id != events.last?.id {
                            SettingsDivider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func statusRow(label: String, count: Int, tone: OperationalStatusTone) -> some View {
        HStack {
            Text(label)
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.text)
            Spacer()
            Text("\(count)")
                .font(RediTypography.data)
                .foregroundStyle(count > 0 ? toneColor(tone) : ColorTheme.textTertiary)
        }
    }

    private func eventTypeBadge(_ type: DiagnosticType) -> some View {
        let (text, color): (String, Color) = {
            switch type {
            case .crash: return ("CRASH", ColorTheme.danger)
            case .error: return ("ERROR", ColorTheme.warning)
            case .degraded: return ("DEGRADED", ColorTheme.info)
            case .recovery: return ("RECOVERY", ColorTheme.ready)
            }
        }()

        return Text(text)
            .font(RediTypography.label)
            .tracking(1.2)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func toneColor(_ tone: OperationalStatusTone) -> Color {
        switch tone {
        case .ready: return ColorTheme.ready
        case .info: return ColorTheme.info
        case .caution: return ColorTheme.warning
        case .danger: return ColorTheme.danger
        case .neutral: return ColorTheme.textTertiary
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
