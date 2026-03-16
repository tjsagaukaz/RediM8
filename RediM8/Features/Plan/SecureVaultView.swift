import AVFoundation
import PDFKit
import PhotosUI
import QuickLook
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

struct SecureVaultView: View {
    @ObservedObject var service: DocumentVaultService
    let scrollToTopRequestID: Int

    @State private var selectedCategory: VaultCategory = .identity
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingFileImporter = false
    @State private var isShowingScanner = false
    @State private var isShowingEmergencyInfoEditor = false
    @State private var notice: VaultNotice?
    @State private var previewItem: VaultPreviewItem?
    @State private var isShowingPrivacyModel = false

    init(service: DocumentVaultService, scrollToTopRequestID: Int = 0) {
        self.service = service
        self.scrollToTopRequestID = scrollToTopRequestID
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Color.clear
                        .frame(height: 0)
                        .id(VaultScrollAnchor.top)

                    CinematicBanner("vault_essentials", height: 160)

                    heroCard
                    vaultStatusRail

                    if service.isUnlocked {
                        unlockedContent
                    } else {
                        lockedContent
                    }

                    privacyCard
                }
                .padding(.horizontal, RediSpacing.screen)
                .padding(.top, RediSpacing.screen)
                .padding(.bottom, RediLayout.commandDockContentInset)
            }
            .onChange(of: scrollToTopRequestID) { _, _ in
                DispatchQueue.main.async {
                    withAnimation(RediMotion.selection) {
                        proxy.scrollTo(VaultScrollAnchor.top, anchor: .top)
                    }
                }
            }
        }
        .navigationTitle("Secure Vault")
        .background(Color.clear)
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                await importPhoto(from: newValue)
                selectedPhotoItem = nil
            }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.pdf, .image, .item],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $isShowingScanner) {
            if VNDocumentCameraViewController.isSupported {
                VaultDocumentScanner { result in
                    isShowingScanner = false
                    handleScanResult(result)
                }
            } else {
                VaultUnsupportedScannerView {
                    isShowingScanner = false
                }
            }
        }
        .sheet(isPresented: $isShowingEmergencyInfoEditor) {
            NavigationStack {
                EmergencyInfoEditorView(initialValue: service.state.emergencyInfo) { value in
                    do {
                        try service.saveEmergencyInfo(value)
                    } catch {
                        notice = VaultNotice(message: error.localizedDescription)
                    }
                }
            }
            .rediSheetPresentation()
        }
        .sheet(item: $previewItem, onDismiss: {
            dismissPreview()
        }) { item in
            VaultQuickLookPreview(item: item)
        }
        .alert(item: $notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("OK")))
        }
    }

    private enum VaultScrollAnchor {
        static let top = "vault-scroll-top"
    }

    private enum VaultHealthAction {
        case emergencyInfo
        case category(VaultCategory)
    }

    private struct VaultHealthItem: Identifiable {
        let title: String
        let detail: String
        let systemImage: String
        let tint: Color
        let isComplete: Bool
        let action: VaultHealthAction

        var id: String { title }
    }

    private var heroCard: some View {
        ModeHeroCard(
            eyebrow: "Offline Protection",
            title: "Secure Vault",
            subtitle: "Encrypted local copies of the documents you need when networks fail or home access is cut off.",
            iconName: "documents",
            accent: ColorTheme.textTertiary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TrustPillGroup(items: [
                    TrustPillItem(title: "Encrypted locally", tone: .neutral),
                    TrustPillItem(title: "Offline ready", tone: .neutral),
                    TrustPillItem(title: "Biometric unlock", tone: .neutral),
                    TrustPillItem(title: "Local only", tone: .neutral)
                ])

                vaultHeroMetrics

                ViewThatFits(in: .horizontal) {
                    vaultHeroActionButtons(axis: .horizontal)
                    vaultHeroActionButtons(axis: .vertical)
                }
            }
        }
    }

    private var vaultStatusRail: some View {
        SystemStatusRail(items: vaultStatusItems, accent: ColorTheme.textTertiary)
    }

    private var privacyCard: some View {
        CollapsiblePanelCard(
            title: "Privacy Model",
            subtitle: service.isUnlocked
                ? "Local-only storage promises and limits once the vault is open."
                : "What stays hidden while the vault is locked.",
            accent: ColorTheme.textTertiary,
            isExpanded: $isShowingPrivacyModel
        ) {
            VStack(alignment: .leading, spacing: 12) {
                vaultPromiseRow(
                    title: "Encrypted locally on this device",
                    message: "Vault documents stay encrypted at rest and only open after device-owner authentication succeeds.",
                    systemImage: "lock.shield.fill",
                    tint: ColorTheme.textTertiary
                )
                vaultPromiseRow(
                    title: "RediM8 cannot read your contents",
                    message: "The app manages the encrypted container and preview access, but it cannot inspect your document contents remotely.",
                    systemImage: "eye.slash.fill",
                    tint: ColorTheme.textTertiary
                )
                vaultPromiseRow(
                    title: "Excluded from cloud backup by default",
                    message: "Vault storage remains local-only unless you explicitly add a future backup option later.",
                    systemImage: "icloud.slash.fill",
                    tint: ColorTheme.textTertiary
                )
            }
        }
    }

    private var lockedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            PanelCard(title: "Locked State", subtitle: "Use Face ID, Touch ID, or passcode to open the vault.") {
                VStack(alignment: .leading, spacing: 12) {
                    TrustPillGroup(items: [
                        TrustPillItem(title: "Names hidden", tone: .neutral),
                        TrustPillItem(title: "Encrypted at rest", tone: .neutral),
                        TrustPillItem(title: "Ready for offline access", tone: .neutral)
                    ])

                    Text("When locked, RediM8 hides document names, keeps emergency records encrypted at rest, and leaves the vault ready for fast owner-confirmed access.")
                        .font(.subheadline)
                        .foregroundStyle(ColorTheme.textSecondary)

                    HStack(spacing: 12) {
                        lockedStateBadge(
                            title: "Docs",
                            value: service.state.documents.isEmpty ? "Empty" : "Hidden",
                            tint: service.state.documents.isEmpty ? ColorTheme.warning : ColorTheme.textTertiary
                        )
                        lockedStateBadge(
                            title: "Emergency Card",
                            value: service.state.emergencyInfo.hasAnyContent ? "Saved" : "Empty",
                            tint: service.state.emergencyInfo.hasAnyContent ? ColorTheme.ready : ColorTheme.warning
                        )
                    }

                    Button {
                        Task { await unlockVault() }
                    } label: {
                        RediCommandCard(
                            title: "Unlock Vault",
                            detail: "Use Face ID, Touch ID, or device passcode to open local documents.",
                            systemImage: "lock.open.fill",
                            tint: ColorTheme.textTertiary,
                            badge: "Biometric",
                            prominence: .accented,
                            layout: .rail
                        )
                    }
                    .buttonStyle(CardPressButtonStyle())

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                        ForEach(service.categories) { category in
                            categoryTile(category: category, count: nil, isSelected: false)
                        }
                    }
                }
            }
        }
    }

    private var unlockedContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            vaultSetupCard

            emergencyInfoSummaryCard

            PanelCard(
                title: "Quick Access",
                subtitle: "Identity, medical, insurance, and contact records first during evacuation"
            ) {
                if service.quickAccessDocuments.isEmpty {
                    Text("No quick-access documents yet. Add identity, medical, insurance, or contact records to surface them here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 12) {
                        ForEach(service.quickAccessDocuments) { document in
                            documentRow(document, largeButtons: true)
                        }
                    }
                }
            }

            PanelCard(title: "Vault Sections", subtitle: "Pick the document set you need right now, then import or open from there.") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(service.categories) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            categoryTile(category: category, count: service.categoryCount(category), isSelected: selectedCategory == category)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            PanelCard(title: selectedCategory.title, subtitle: selectedCategory.subtitle) {
                VStack(spacing: 12) {
                    if service.documents(in: selectedCategory).isEmpty {
                        Text("No \(selectedCategory.title.lowercased()) documents stored offline yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(service.documents(in: selectedCategory)) { document in
                            documentRow(document, largeButtons: false)
                        }
                    }
                }
            }

            PanelCard(title: "Add to \(selectedCategory.title)", subtitle: "Scan or import a local file into the currently selected vault section.") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    quickActionButton(title: "Scan", subtitle: "Camera to PDF", iconName: "camera", tint: ColorTheme.textTertiary) {
                        isShowingScanner = true
                    }
                    quickActionButton(title: "Import PDF", subtitle: "Files app", iconName: "documents", tint: ColorTheme.textTertiary) {
                        isShowingFileImporter = true
                    }
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        quickActionButtonLabel(title: "Import Photo", subtitle: "Photo library", iconName: "image", tint: ColorTheme.textTertiary)
                    }
                    .buttonStyle(.plain)

                    quickActionButton(title: "Import File", subtitle: "Any local file", iconName: "folder", tint: ColorTheme.textTertiary) {
                        isShowingFileImporter = true
                    }
                }
            }
        }
    }

    private var vaultSetupCard: some View {
        PanelCard(
            title: "Vault Setup",
            subtitle: "\(vaultSetupCompletedCount)/\(vaultHealthItems.count) essentials ready for evacuation"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VAULT READINESS")
                            .font(RediTypography.caption)
                            .foregroundStyle(ColorTheme.textTertiary)

                        Text("\(vaultReadinessPercentage)%")
                            .font(RediTypography.dataLarge)
                            .foregroundStyle(ColorTheme.text)
                    }

                    Spacer(minLength: 0)

                    Text(vaultNextActionText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ColorTheme.textSecondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }

                vaultProgressBar

                VStack(spacing: 10) {
                    ForEach(vaultHealthItems) { item in
                        Button {
                            handleVaultHealthSelection(item)
                        } label: {
                            vaultHealthRow(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emergencyInfoSummaryCard: some View {
        PanelCard(
            title: "Emergency Info",
            subtitle: "Medical and contact summary for you, family, or responders."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    vaultMiniStatus(
                        title: "Status",
                        value: service.state.emergencyInfo.hasAnyContent ? "Saved" : "Add now",
                        tint: service.state.emergencyInfo.hasAnyContent ? ColorTheme.ready : ColorTheme.warning
                    )
                    vaultMiniStatus(
                        title: "Priority",
                        value: "Responder first",
                        tint: ColorTheme.textTertiary
                    )
                }

                if service.state.emergencyInfo.hasAnyContent {
                    emergencyInfoLine(label: "Blood Type", value: service.state.emergencyInfo.bloodType)
                    emergencyInfoLine(label: "Allergies", value: service.state.emergencyInfo.allergies)
                    emergencyInfoLine(label: "Medications", value: service.state.emergencyInfo.medications)
                    emergencyInfoLine(label: "Contacts", value: service.state.emergencyInfo.emergencyContacts)
                    emergencyInfoLine(label: "Medical Notes", value: service.state.emergencyInfo.medicalNotes)
                } else {
                    Text("No emergency summary saved yet. Add blood type, allergies, medications, and emergency contacts now.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    isShowingEmergencyInfoEditor = true
                } label: {
                    RediCommandCard(
                        title: "Edit Emergency Info",
                        detail: "Update blood type, allergies, medications, and emergency contacts.",
                        systemImage: "heart.text.square.fill",
                        tint: ColorTheme.ready,
                        badge: service.state.emergencyInfo.hasAnyContent ? "Saved" : "Add Now",
                        prominence: .accented,
                        layout: .rail
                    )
                }
                .buttonStyle(CardPressButtonStyle())
            }
        }
    }

    private var vaultHeroMetrics: some View {
        LazyVGrid(columns: vaultMetricColumns, spacing: 12) {
            vaultMetricTile(
                title: "Documents",
                value: totalDocumentLabel,
                detail: service.isUnlocked ? "Stored locally" : "Names hidden",
                iconName: "documents",
                tint: ColorTheme.textTertiary
            )
            vaultMetricTile(
                title: "Quick Access",
                value: quickAccessLabel,
                detail: service.isUnlocked ? "Evacuation-first set" : "Unlock to reveal",
                iconName: "shield",
                tint: ColorTheme.textTertiary
            )
            vaultMetricTile(
                title: "Emergency Card",
                value: emergencyInfoLabel,
                detail: service.isUnlocked ? "Responder summary" : "Protected while locked",
                iconName: "medical",
                tint: emergencyInfoTint
            )
            vaultMetricTile(
                title: "Backup",
                value: "Local Only",
                detail: "Cloud excluded by default",
                iconName: "internaldrive.fill",
                tint: ColorTheme.textTertiary
            )
        }
    }

    @ViewBuilder
    private func vaultHeroActionButtons(axis: Axis.Set) -> some View {
        let stack = Group {
            Button {
                if service.isUnlocked {
                    service.lock()
                    RediHaptics.softImpact()
                } else {
                    Task { await unlockVault() }
                }
            } label: {
                RediCommandCard(
                    title: service.isUnlocked ? "Lock Vault" : "Unlock Vault",
                    detail: service.isUnlocked
                        ? "Secure the local vault again and hide all document names."
                        : "Use owner authentication to open encrypted local documents.",
                    systemImage: service.isUnlocked ? "lock.fill" : "lock.open.fill",
                    tint: ColorTheme.textTertiary,
                    badge: service.isUnlocked ? "Secure" : "Open",
                    prominence: .accented,
                    layout: .rail
                )
            }
            .buttonStyle(CardPressButtonStyle())

            if service.isUnlocked {
                Button {
                    isShowingEmergencyInfoEditor = true
                } label: {
                    RediCommandCard(
                        title: "Emergency Info",
                        detail: "Open the responder-facing medical and contact summary.",
                        systemImage: "heart.text.square.fill",
                        tint: ColorTheme.ready,
                        badge: service.state.emergencyInfo.hasAnyContent ? "Saved" : "Add Now",
                        prominence: .neutral,
                        layout: .rail
                    )
                }
                .buttonStyle(CardPressButtonStyle())
            }
        }

        if axis == .horizontal {
            HStack(spacing: 12) {
                stack
            }
        } else {
            VStack(spacing: 12) {
                stack
            }
        }
    }

    private func emergencyInfoLine(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)
            Text(value.nilIfBlank ?? "Not set")
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)
        }
    }

    private func lockedStateBadge(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func vaultMiniStatus(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var vaultMetricColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 148), spacing: 12, alignment: .top)
        ]
    }

    private var vaultStatusItems: [OperationalStatusItem] {
        [
            OperationalStatusItem(
                iconName: "lock.shield.fill",
                label: "Vault",
                value: service.isUnlocked ? "Unlocked" : "Locked",
                tone: service.isUnlocked ? .ready : .neutral
            ),
            OperationalStatusItem(
                iconName: "documents",
                label: "Documents",
                value: totalDocumentLabel,
                tone: service.isUnlocked ? .info : .neutral
            ),
            OperationalStatusItem(
                iconName: "medical",
                label: "Emergency Card",
                value: emergencyInfoLabel,
                tone: service.isUnlocked ? (service.state.emergencyInfo.hasAnyContent ? .ready : .caution) : .neutral
            ),
            OperationalStatusItem(
                iconName: "icloud.slash.fill",
                label: "Backup",
                value: "Local Only",
                tone: .info
            )
        ]
    }

    private var totalDocumentLabel: String {
        service.isUnlocked ? "\(service.state.documents.count)" : "Hidden"
    }

    private var quickAccessLabel: String {
        service.isUnlocked ? "\(service.quickAccessDocuments.count)" : "Locked"
    }

    private var emergencyInfoLabel: String {
        if !service.isUnlocked {
            return "Locked"
        }

        return service.state.emergencyInfo.hasAnyContent ? "Saved" : "Add Now"
    }

    private var emergencyInfoTint: Color {
        if !service.isUnlocked {
            return ColorTheme.textTertiary
        }

        return service.state.emergencyInfo.hasAnyContent ? ColorTheme.ready : ColorTheme.warning
    }

    private var vaultHealthItems: [VaultHealthItem] {
        [
            VaultHealthItem(
                title: "Emergency Info",
                detail: service.state.emergencyInfo.hasAnyContent
                    ? "Responder summary saved"
                    : "Add blood type, medications, and contacts",
                systemImage: "heart.text.square.fill",
                tint: ColorTheme.ready,
                isComplete: service.state.emergencyInfo.hasAnyContent,
                action: .emergencyInfo
            ),
            VaultHealthItem(
                title: "Identity",
                detail: vaultCategoryHealthDetail(.identity, missingMessage: "Add passport or driver licence"),
                systemImage: "person.text.rectangle.fill",
                tint: ColorTheme.textTertiary,
                isComplete: service.categoryCount(.identity) > 0,
                action: .category(.identity)
            ),
            VaultHealthItem(
                title: "Medical",
                detail: vaultCategoryHealthDetail(.medical, missingMessage: "Add prescriptions and care records"),
                systemImage: "cross.case.fill",
                tint: ColorTheme.textTertiary,
                isComplete: service.categoryCount(.medical) > 0,
                action: .category(.medical)
            ),
            VaultHealthItem(
                title: "Insurance",
                detail: vaultCategoryHealthDetail(.insurance, missingMessage: "Add policy numbers and claim details"),
                systemImage: "shield.fill",
                tint: ColorTheme.textTertiary,
                isComplete: service.categoryCount(.insurance) > 0,
                action: .category(.insurance)
            ),
            VaultHealthItem(
                title: "Emergency Contacts",
                detail: vaultCategoryHealthDetail(.emergencyContacts, missingMessage: "Add a call tree or contact list"),
                systemImage: "person.2.fill",
                tint: ColorTheme.textSecondary,
                isComplete: service.categoryCount(.emergencyContacts) > 0,
                action: .category(.emergencyContacts)
            )
        ]
    }

    private var vaultSetupCompletedCount: Int {
        vaultHealthItems.filter(\.isComplete).count
    }

    private var vaultReadinessPercentage: Int {
        guard !vaultHealthItems.isEmpty else { return 0 }
        return Int((Double(vaultSetupCompletedCount) / Double(vaultHealthItems.count) * 100).rounded())
    }

    private var vaultNextActionText: String {
        if let firstIncomplete = vaultHealthItems.first(where: { !$0.isComplete }) {
            return "Add \(firstIncomplete.title.lowercased()) next"
        }

        return "All essentials stored offline"
    }

    private var vaultProgressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(ColorTheme.panelElevated)

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(ColorTheme.ready)
                    .frame(width: proxy.size.width * CGFloat(vaultReadinessPercentage) / 100)
            }
        }
        .frame(height: 14)
    }

    private func vaultHealthRow(_ item: VaultHealthItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(item.isComplete ? item.tint.opacity(0.14) : ColorTheme.panelElevated)
                    .frame(width: 40, height: 40)

                Image(systemName: item.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(item.isComplete ? item.tint : ColorTheme.textTertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)

                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "arrow.right.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(item.isComplete ? ColorTheme.ready : ColorTheme.warning)

                Text(item.isComplete ? "Ready" : "Add")
                    .font(RediTypography.caption)
                    .foregroundStyle(item.isComplete ? ColorTheme.ready : ColorTheme.warning)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
    }

    private func vaultCategoryHealthDetail(_ category: VaultCategory, missingMessage: String) -> String {
        let count = service.categoryCount(category)
        guard count > 0 else { return missingMessage }
        return count == 1 ? "1 document stored" : "\(count) documents stored"
    }

    private func handleVaultHealthSelection(_ item: VaultHealthItem) {
        switch item.action {
        case .emergencyInfo:
            isShowingEmergencyInfoEditor = true
        case let .category(category):
            selectedCategory = category
        }

        RediHaptics.selection()
    }

    private func vaultMetricTile(
        title: String,
        value: String,
        detail: String,
        iconName: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 34, height: 34)

                    RediIcon(iconName)
                        .foregroundStyle(tint)
                        .frame(width: 16, height: 16)
                }

                Spacer(minLength: 0)
            }

            Text(title.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)

            Text(value)
                .font(RediTypography.dataLarge)
                .foregroundStyle(ColorTheme.text)
                .contentTransition(.numericText())

            Text(detail)
                .font(.caption)
                .foregroundStyle(ColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(16)
        .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous))
    }

    private func vaultPromiseRow(
        title: String,
        message: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 42, height: 42)

                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
    }

    private func categoryTile(category: VaultCategory, count: Int?, isSelected: Bool) -> some View {
        let tint = isSelected ? ColorTheme.textTertiary : ColorTheme.textTertiary

        return VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill((isSelected ? ColorTheme.textTertiary : ColorTheme.panelElevated).opacity(isSelected ? 0.16 : 0.92))
                    .frame(width: 40, height: 40)

                RediIcon(category.iconName)
                    .foregroundStyle(tint)
                    .frame(width: 18, height: 18)
            }

            Text(category.title)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)

            Text(count.map { "\($0) stored" } ?? "Unlock to view")
                .font(.caption)
                .foregroundStyle(ColorTheme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
    }

    private func categoryChip(_ category: VaultCategory) -> some View {
        HStack(spacing: 8) {
            RediIcon(category.iconName)
                .foregroundStyle(selectedCategory == category ? ColorTheme.textTertiary : ColorTheme.textTertiary)
                .frame(width: 16, height: 16)
            Text(category.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ColorTheme.text)
            Text("\(service.categoryCount(category))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ColorTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            selectedCategory == category ? ColorTheme.textTertiary.opacity(0.16) : ColorTheme.panel.opacity(0.82),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .stroke((selectedCategory == category ? ColorTheme.textTertiary : ColorTheme.dividerStrong).opacity(0.26), lineWidth: 1)
        )
    }

    private func quickActionButton(
        title: String,
        subtitle: String,
        iconName: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            quickActionButtonLabel(title: title, subtitle: subtitle, iconName: iconName, tint: tint)
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private func quickActionButtonLabel(title: String, subtitle: String, iconName: String, tint: Color) -> some View {
        RediCommandCard(
            title: title,
            detail: subtitle,
            iconName: iconName,
            tint: tint,
            prominence: .neutral,
            minHeight: 110
        )
    }

    private func documentRow(_ document: VaultDocument, largeButtons: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                RediIcon(document.category.iconName)
                    .foregroundStyle(ColorTheme.textTertiary)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text(document.displayName)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    Text("\(document.source.title) • \(document.formattedSize)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            vaultDocumentMetaLabel(
                                "Added \(DateFormatter.rediM8MonthYear.string(from: document.createdAt))",
                                systemImage: "calendar"
                            )
                            vaultDocumentMetaLabel(
                                document.updatedAt.rediM8FreshnessLabel(),
                                systemImage: "clock"
                            )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            vaultDocumentMetaLabel(
                                "Added \(DateFormatter.rediM8MonthYear.string(from: document.createdAt))",
                                systemImage: "calendar"
                            )
                            vaultDocumentMetaLabel(
                                document.updatedAt.rediM8FreshnessLabel(),
                                systemImage: "clock"
                            )
                        }
                    }
                }

                Spacer()
            }

            TrustPillGroup(items: [
                TrustPillItem(title: "Encrypted locally", tone: .neutral),
                TrustPillItem(title: "Offline ready", tone: .neutral)
            ])

            if let pageCount = document.pageCount {
                Text(pageCount == 1 ? "1 page" : "\(pageCount) pages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if largeButtons {
                    Button("Open") {
                        openPreview(for: document)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                } else {
                    Button("Open") {
                        openPreview(for: document)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }

                Button("Delete") {
                    do {
                        try service.deleteDocument(document.id)
                    } catch {
                        notice = VaultNotice(message: error.localizedDescription)
                    }
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
        .padding(16)
        .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
    }

    private func vaultDocumentMetaLabel(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(ColorTheme.textSecondary)
    }

    private func unlockVault() async {
        do {
            try await service.unlock()
            RediHaptics.success()
        } catch {
            RediHaptics.warning()
            notice = VaultNotice(message: error.localizedDescription)
        }
    }

    private func importPhoto(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw DocumentVaultError.importFailed("The selected photo could not be read.")
            }

            let suggestedName = item.itemIdentifier?.nilIfBlank ?? "Photo"
            let contentType = item.supportedContentTypes.first ?? .jpeg
            try service.addDocument(
                VaultImportPayload(
                    data: data,
                    displayName: suggestedName,
                    filename: "\(suggestedName).\(contentType.preferredFilenameExtension ?? "jpg")",
                    contentType: contentType,
                    source: .photoImport,
                    pageCount: 1
                ),
                to: selectedCategory
            )
        } catch {
            notice = VaultNotice(message: error.localizedDescription)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                return
            }

            let isScoped = url.startAccessingSecurityScopedResource()
            defer {
                if isScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let contentType = UTType(filenameExtension: url.pathExtension) ?? .data
            let displayName = url.deletingPathExtension().lastPathComponent
            try service.addDocument(
                VaultImportPayload(
                    data: data,
                    displayName: displayName,
                    filename: url.lastPathComponent,
                    contentType: contentType,
                    source: contentType == .pdf ? .pdfImport : .fileImport,
                    pageCount: contentType == .pdf ? PDFDocument(data: data)?.pageCount : nil
                ),
                to: selectedCategory
            )
        } catch {
            notice = VaultNotice(message: error.localizedDescription)
        }
    }

    private func handleScanResult(_ result: Result<VaultImportPayload, Error>) {
        do {
            let payload = try result.get()
            try service.addDocument(payload, to: selectedCategory)
        } catch {
            notice = VaultNotice(message: error.localizedDescription)
        }
    }

    private func openPreview(for document: VaultDocument) {
        do {
            let url = try service.temporaryPreviewURL(for: document)
            previewItem = VaultPreviewItem(url: url, title: document.displayName)
        } catch {
            notice = VaultNotice(message: error.localizedDescription)
        }
    }

    private func dismissPreview() {
        if let previewItem {
            service.releaseTemporaryPreviewURL(previewItem.url)
        }
        previewItem = nil
    }
}

struct EmergencyDocumentsQuickView: View {
    @ObservedObject var service: DocumentVaultService
    @Environment(\.dismiss) private var dismiss
    @State private var notice: VaultNotice?
    @State private var previewItem: VaultPreviewItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ModeHeroCard(
                        eyebrow: "Emergency Access",
                        title: "Emergency Documents",
                        subtitle: "Open local ID, insurance, and medical records quickly, without pretending the device is safer than it is.",
                        iconName: "documents",
                        accent: ColorTheme.danger
                    ) {
                        TrustPillGroup(items: [
                            TrustPillItem(title: "Encrypted locally", tone: .neutral),
                            TrustPillItem(title: "Offline only", tone: .neutral),
                            TrustPillItem(title: "Biometric unlock", tone: .neutral)
                        ])
                    }

                    if service.isUnlocked {
                        PanelCard(title: "Emergency Info", subtitle: "Responder-friendly summary") {
                            VStack(alignment: .leading, spacing: 10) {
                                emergencyLine("Blood Type", value: service.state.emergencyInfo.bloodType)
                                emergencyLine("Allergies", value: service.state.emergencyInfo.allergies)
                                emergencyLine("Medications", value: service.state.emergencyInfo.medications)
                                emergencyLine("Contacts", value: service.state.emergencyInfo.emergencyContacts)
                                emergencyLine("Medical Notes", value: service.state.emergencyInfo.medicalNotes)
                            }
                        }

                        PanelCard(title: "Quick Documents", subtitle: "Identity, insurance, medical, and contacts first") {
                            if service.quickAccessDocuments.isEmpty {
                                Text("No quick-access vault documents saved yet.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(service.quickAccessDocuments) { document in
                                        Button {
                                            openPreview(for: document)
                                        } label: {
                                            HStack(alignment: .top, spacing: 12) {
                                                RediIcon(document.category.iconName)
                                                    .foregroundStyle(ColorTheme.accent)
                                                    .frame(width: 22, height: 22)

                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(document.displayName)
                                                        .font(RediTypography.bodyStrong)
                                                        .foregroundStyle(ColorTheme.text)
                                                    Text(document.category.title)
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                }

                                                Spacer()
                                            }
                                            .padding(16)
                                            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                                            .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        }
                                        .buttonStyle(CardPressButtonStyle())
                                    }
                                }
                            }
                        }
                    } else {
                        PanelCard(title: "Locked", subtitle: "Use Face ID, Touch ID, or passcode") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("RediM8 keeps these documents encrypted locally until device ownership is confirmed.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Button("Unlock Emergency Documents") {
                                    Task { await unlockEmergencyDocuments() }
                                }
                                .buttonStyle(PrimaryActionButtonStyle())
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Emergency Documents")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $previewItem, onDismiss: {
                dismissPreview()
            }) { item in
                VaultQuickLookPreview(item: item)
            }
            .alert(item: $notice) { notice in
                Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func unlockEmergencyDocuments() async {
        do {
            try await service.unlock()
            RediHaptics.success()
        } catch {
            RediHaptics.warning()
            notice = VaultNotice(message: error.localizedDescription)
        }
    }

    private func emergencyLine(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)
            Text(value.nilIfBlank ?? "Not set")
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)
        }
    }

    private func openPreview(for document: VaultDocument) {
        do {
            let url = try service.temporaryPreviewURL(for: document)
            previewItem = VaultPreviewItem(url: url, title: document.displayName)
        } catch {
            notice = VaultNotice(message: error.localizedDescription)
        }
    }

    private func dismissPreview() {
        if let previewItem {
            service.releaseTemporaryPreviewURL(previewItem.url)
        }
        previewItem = nil
    }
}

private struct EmergencyInfoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: EmergencyInfoCard
    let onSave: (EmergencyInfoCard) -> Void

    init(initialValue: EmergencyInfoCard, onSave: @escaping (EmergencyInfoCard) -> Void) {
        _draft = State(initialValue: initialValue)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Emergency Summary") {
                TextField("Blood type", text: $draft.bloodType)
                TextField("Allergies", text: $draft.allergies, axis: .vertical)
                TextField("Medications", text: $draft.medications, axis: .vertical)
                TextField("Emergency contacts", text: $draft.emergencyContacts, axis: .vertical)
                TextField("Medical notes", text: $draft.medicalNotes, axis: .vertical)
            }
        }
        .navigationTitle("Emergency Info")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    onSave(draft)
                    dismiss()
                }
            }
        }
    }
}

private struct VaultNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init(title: String = "Secure Vault", message: String) {
        self.title = title
        self.message = message
    }
}

private struct VaultPreviewItem: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
}

private struct VaultQuickLookPreview: UIViewControllerRepresentable {
    let item: VaultPreviewItem

    func makeCoordinator() -> Coordinator {
        Coordinator(item: item)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        context.coordinator.item = item
        uiViewController.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var item: VaultPreviewItem

        init(item: VaultPreviewItem) {
            self.item = item
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            item.url as NSURL
        }
    }
}

private struct VaultDocumentScanner: UIViewControllerRepresentable {
    let completion: (Result<VaultImportPayload, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completion: (Result<VaultImportPayload, Error>) -> Void

        init(completion: @escaping (Result<VaultImportPayload, Error>) -> Void) {
            self.completion = completion
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            completion(.failure(DocumentVaultError.importFailed("Scan cancelled.")))
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            completion(.failure(error))
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            do {
                let payload = try makePayload(from: scan)
                completion(.success(payload))
            } catch {
                completion(.failure(error))
            }
        }

        private func makePayload(from scan: VNDocumentCameraScan) throws -> VaultImportPayload {
            let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
            let data = renderer.pdfData { context in
                for index in 0..<scan.pageCount {
                    let image = scan.imageOfPage(at: index)
                    context.beginPage()
                    let pageRect = AVMakeRect(aspectRatio: image.size, insideRect: CGRect(x: 24, y: 24, width: 564, height: 744))
                    image.draw(in: pageRect)
                }
            }

            let timestamp = DateFormatter.rediM8Short.string(from: .now).replacingOccurrences(of: " ", with: "-")
            return VaultImportPayload(
                data: data,
                displayName: "Scan \(timestamp)",
                filename: "Scan-\(timestamp).pdf",
                contentType: .pdf,
                source: .scan,
                pageCount: scan.pageCount
            )
        }
    }
}

private struct VaultUnsupportedScannerView: View {
    let dismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Document scanning is unavailable on this device.")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ColorTheme.text)

                Text("Use Import PDF, Import Photo, or Import File instead.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Spacer()
            }
            .padding(24)
            .navigationTitle("Scan Unavailable")
        }
    }
}
