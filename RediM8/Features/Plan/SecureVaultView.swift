import AVFoundation
import PDFKit
import PhotosUI
import QuickLook
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

struct SecureVaultView: View {
    @ObservedObject var service: DocumentVaultService
    let isProUser: Bool
    let storeKitService: StoreKitService?
    let scrollToTopRequestID: Int

    @State private var selectedCategory: VaultCategory = .identity
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingFileImporter = false
    @State private var isShowingScanner = false
    @State private var isShowingEmergencyInfoEditor = false
    @State private var notice: VaultNotice?
    @State private var previewItem: VaultPreviewItem?
    @State private var responderAccessItem: VaultResponderAccessItem?
    @State private var isShowingPrivacyModel = false
    @State private var isShowingProPaywall = false

    init(service: DocumentVaultService, isProUser: Bool = false, storeKitService: StoreKitService? = nil, scrollToTopRequestID: Int = 0) {
        self.service = service
        self.isProUser = isProUser
        self.storeKitService = storeKitService
        self.scrollToTopRequestID = scrollToTopRequestID
    }

    private var totalDocumentCount: Int {
        service.state.documents.count
    }

    private var canAddDocument: Bool {
        ProFeatureGate.allowsAdditionalVaultDocuments(isProUser: isProUser, currentDocumentCount: totalDocumentCount)
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
                    vaultStatusCard

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
        .sheet(item: $responderAccessItem) { item in
            NavigationStack {
                VaultResponderAccessView(item: item)
            }
            .rediSheetPresentation()
        }
        .alert(item: $notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $isShowingProPaywall) {
            if let storeKitService {
                NavigationStack {
                    RediM8ProView(
                        storeKitService: storeKitService,
                        emergencyUnlockState: .inactive
                    )
                }
                .rediSheetPresentation()
            }
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
            eyebrow: "Emergency Access",
            title: "Secure Vault",
            subtitle: "Your identity, medical info, and key records stay available without signal when you need them most.",
            iconName: "documents",
            accent: ColorTheme.textTertiary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TrustPillGroup(items: [
                    TrustPillItem(title: "Encrypted locally", tone: .neutral),
                    TrustPillItem(title: "Offline ready", tone: .neutral),
                    TrustPillItem(title: "Responder card", tone: .neutral),
                    TrustPillItem(title: "Owner authentication", tone: .neutral)
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
            title: "Security Model",
            subtitle: "How Secure Vault stays local, protected, and usable when signal is gone.",
            accent: ColorTheme.textTertiary,
            isExpanded: $isShowingPrivacyModel
        ) {
            VStack(alignment: .leading, spacing: 12) {
                securityBullet("Stored only on this device")
                securityBullet("Encrypted at rest")
                securityBullet("Not accessible by RediM8 servers")
                securityBullet("Not backed up to cloud by default")
                securityBullet("Responder access can reveal emergency info without opening the full document list")
            }
        }
    }

    private var lockedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            PanelCard(title: "Secure Access", subtitle: "Document names stay hidden until device ownership is confirmed.") {
                VStack(alignment: .leading, spacing: 12) {
                    TrustPillGroup(items: [
                        TrustPillItem(title: "Names hidden", tone: .neutral),
                        TrustPillItem(title: "Encrypted at rest", tone: .neutral),
                        TrustPillItem(title: "Emergency info only", tone: .neutral)
                    ])

                    Text("Use secure access for the full vault. Use responder access to reveal the emergency card only when someone needs your medical and contact summary fast.")
                        .font(.subheadline)
                        .foregroundStyle(ColorTheme.textSecondary)

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
            emergencyInfoSummaryCard

            PanelCard(
                title: "Priority Access",
                subtitle: "These documents appear first during evacuation or identity checks under pressure."
            ) {
                if service.quickAccessDocuments.isEmpty {
                    Text("Nothing is staged for priority access yet. Add identity, medical, insurance, or contact records to bring them to the front.")
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

            PanelCard(title: "Document Sets", subtitle: "Work one record set at a time so critical identity, medical, and insurance files stay easy to stage.") {
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
                        Text("No \(selectedCategory.title.lowercased()) documents are staged for offline access yet.")
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

            PanelCard(
                title: "Add Documents",
                subtitle: canAddDocument
                    ? "Scan or import into the selected document set."
                    : "Free tier includes \(ProFeatureGate.freeVaultDocumentLimit) documents. Unlock expanded vault for unlimited storage."
            ) {
                if canAddDocument {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                        quickActionButton(title: "Scan", subtitle: "Camera", iconName: "camera", tint: ColorTheme.textTertiary) {
                            isShowingScanner = true
                        }
                        quickActionButton(title: "Import PDF", subtitle: "Files", iconName: "documents", tint: ColorTheme.textTertiary) {
                            isShowingFileImporter = true
                        }
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            quickActionButtonLabel(title: "Import Photo", subtitle: "Gallery", iconName: "image", tint: ColorTheme.textTertiary)
                        }
                        .buttonStyle(.plain)

                        quickActionButton(title: "Import File", subtitle: "Any local file", iconName: "folder", tint: ColorTheme.textTertiary) {
                            isShowingFileImporter = true
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(totalDocumentCount)/\(ProFeatureGate.freeVaultDocumentLimit) free documents used")
                            .font(RediTypography.bodyStrong)
                            .foregroundStyle(ColorTheme.text)
                        Button {
                            isShowingProPaywall = true
                        } label: {
                            Text(ProFeatureGate.paywallTitle(for: .vault))
                                .font(RediTypography.button)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                    }
                }
            }
        }
    }

    private var vaultStatusCard: some View {
        PanelCard(
            title: "Vault Status",
            subtitle: vaultStatusHeadline
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VAULT STATUS")
                            .font(RediTypography.caption)
                            .foregroundStyle(ColorTheme.textTertiary)

                        Text(vaultStatusHeadline)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(ColorTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    vaultMiniStatus(
                        title: "Last Updated",
                        value: vaultLastUpdatedShortLabel,
                        tint: vaultLastUpdatedTint
                    )
                }

                Text(vaultPriorityLine)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(vaultStatusTint)

                Text(vaultLastUpdatedLine)
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.textSecondary)

                vaultProgressBar

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 12)], spacing: 12) {
                    vaultMiniStatus(
                        title: "Documents",
                        value: documentsStatusValue,
                        tint: documentsStatusTint
                    )
                    vaultMiniStatus(
                        title: "Priority Access",
                        value: priorityAccessStatusValue,
                        tint: priorityAccessStatusTint
                    )
                    vaultMiniStatus(
                        title: "Emergency Card",
                        value: emergencyCardStatusValue,
                        tint: emergencyCardStatusTint
                    )
                    vaultMiniStatus(
                        title: "Secure Access",
                        value: service.isUnlocked ? "OPEN" : "LOCKED",
                        tint: service.isUnlocked ? ColorTheme.ready : ColorTheme.textTertiary
                    )
                }

                if service.isUnlocked {
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
                } else {
                    Text("Use secure access for the full vault. Responder access shows the emergency card only, without revealing the rest of the document list.")
                        .font(.subheadline)
                        .foregroundStyle(ColorTheme.textSecondary)
                }
            }
        }
    }

    private var emergencyInfoSummaryCard: some View {
        PanelCard(
            title: "Emergency Card",
            subtitle: "Used by responders if you cannot communicate."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    vaultMiniStatus(
                        title: "Status",
                        value: service.state.emergencyInfo.hasAnyContent ? "Configured" : "Required",
                        tint: service.state.emergencyInfo.hasAnyContent ? ColorTheme.ready : ColorTheme.warning
                    )
                    vaultMiniStatus(
                        title: "Responder Access",
                        value: service.state.emergencyInfo.hasAnyContent ? "Ready" : "Not Ready",
                        tint: service.state.emergencyInfo.hasAnyContent ? ColorTheme.ready : ColorTheme.warning
                    )
                }

                if service.state.emergencyInfo.hasAnyContent {
                    emergencyInfoLine(label: "Blood Type", value: service.state.emergencyInfo.bloodType)
                    emergencyInfoLine(label: "Allergies", value: service.state.emergencyInfo.allergies)
                    emergencyInfoLine(label: "Medications", value: service.state.emergencyInfo.medications)
                    emergencyInfoLine(label: "Contacts", value: service.state.emergencyInfo.emergencyContacts)
                    emergencyInfoLine(label: "Medical Notes", value: service.state.emergencyInfo.medicalNotes)
                } else {
                    Text("No responder summary is configured yet. Add blood type, allergies, medications, and emergency contacts now.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    isShowingEmergencyInfoEditor = true
                } label: {
                    RediCommandCard(
                        title: service.state.emergencyInfo.hasAnyContent ? "Update Emergency Card" : "Add Emergency Card",
                        detail: service.state.emergencyInfo.hasAnyContent
                            ? "Review the responder-facing medical and contact summary."
                            : "Used by responders if you cannot communicate.",
                        systemImage: "heart.text.square.fill",
                        tint: ColorTheme.ready,
                        badge: service.state.emergencyInfo.hasAnyContent ? "Configured" : "Required",
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
                value: documentsStatusValue,
                detail: documentsMetricDetail,
                iconName: "documents",
                tint: documentsStatusTint
            )
            vaultMetricTile(
                title: "Priority Access",
                value: priorityAccessStatusValue,
                detail: priorityAccessMetricDetail,
                iconName: "shield",
                tint: priorityAccessStatusTint
            )
            vaultMetricTile(
                title: "Emergency Card",
                value: emergencyCardStatusValue,
                detail: emergencyCardMetricDetail,
                iconName: "medical",
                tint: emergencyCardStatusTint
            )
            vaultMetricTile(
                title: "Last Updated",
                value: vaultLastUpdatedShortLabel,
                detail: vaultLastUpdatedMetricDetail,
                iconName: "clock",
                tint: vaultLastUpdatedTint
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
                    title: service.isUnlocked ? "Lock Secure Access" : "Access Documents",
                    detail: service.isUnlocked
                        ? "Secure the local vault again and hide all document names."
                        : "Open encrypted local records with Face ID, Touch ID, or passcode.",
                    systemImage: service.isUnlocked ? "lock.fill" : "lock.open.fill",
                    tint: ColorTheme.textTertiary,
                    badge: service.isUnlocked ? "Secure" : "Owner Check",
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
                        title: "Emergency Card",
                        detail: "Review the responder-facing medical and contact summary.",
                        systemImage: "heart.text.square.fill",
                        tint: ColorTheme.ready,
                        badge: service.state.emergencyInfo.hasAnyContent ? "Configured" : "Required",
                        prominence: .neutral,
                        layout: .rail
                    )
                }
                .buttonStyle(CardPressButtonStyle())
            } else if responderAccessAvailable {
                Button {
                    Task { await openResponderAccess() }
                } label: {
                    RediCommandCard(
                        title: "Responder Access",
                        detail: "Show emergency info only without opening the full document list.",
                        systemImage: "heart.text.square.fill",
                        tint: ColorTheme.ready,
                        badge: "Emergency Only",
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
                label: "Vault Status",
                value: vaultRailStatusValue,
                tone: vaultRailStatusTone
            ),
            OperationalStatusItem(
                iconName: "documents",
                label: "Documents",
                value: documentsRailValue,
                tone: documentsRailTone
            ),
            OperationalStatusItem(
                iconName: "medical",
                label: "Emergency Card",
                value: emergencyCardRailValue,
                tone: emergencyCardRailTone
            ),
            OperationalStatusItem(
                iconName: "shield",
                label: "Priority Access",
                value: priorityAccessRailValue,
                tone: priorityAccessRailTone
            )
        ]
    }

    private var vaultHealthItems: [VaultHealthItem] {
        [
            VaultHealthItem(
                title: "Emergency Card",
                detail: service.state.emergencyInfo.hasAnyContent
                    ? "Responder summary is configured"
                    : "REQUIRED. Used by responders if you cannot communicate",
                systemImage: "heart.text.square.fill",
                tint: ColorTheme.ready,
                isComplete: service.state.emergencyInfo.hasAnyContent,
                action: .emergencyInfo
            ),
            VaultHealthItem(
                title: "Identity",
                detail: vaultCategoryHealthDetail(.identity, missingMessage: "Add passport, licence, or identity proof"),
                systemImage: "person.text.rectangle.fill",
                tint: ColorTheme.textTertiary,
                isComplete: service.categoryCount(.identity) > 0,
                action: .category(.identity)
            ),
            VaultHealthItem(
                title: "Medical",
                detail: vaultCategoryHealthDetail(.medical, missingMessage: "Add prescriptions, allergies, and care records"),
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
                detail: vaultCategoryHealthDetail(.emergencyContacts, missingMessage: "Add a call tree or printed contact list"),
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

    private var vaultReadinessProgress: Double {
        if service.isUnlocked {
            guard !vaultHealthItems.isEmpty else { return 0 }
            return Double(vaultSetupCompletedCount) / Double(vaultHealthItems.count)
        }

        if !service.metadata.isIndexed {
            return 0.25
        }

        var completed = 0
        if resolvedDocumentCount > 0 { completed += 1 }
        if resolvedQuickAccessCount > 0 { completed += 1 }
        if emergencyCardConfigured { completed += 1 }
        return Double(completed) / 3.0
    }

    private var vaultStatusHeadline: String {
        if !service.metadata.isIndexed && !service.isUnlocked {
            return "Secure access required to verify"
        }

        if emergencyCardConfigured && resolvedQuickAccessCount > 0 {
            return "Ready for emergency access"
        }

        if resolvedDocumentCount == 0 && !emergencyCardConfigured {
            return "Not ready for emergency use"
        }

        if !emergencyCardConfigured {
            return "Emergency card required"
        }

        if resolvedQuickAccessCount == 0 {
            return "Priority access not staged"
        }

        return "Needs emergency setup"
    }

    private var vaultProgressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(ColorTheme.panelElevated)

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(vaultStatusTint)
                    .frame(width: proxy.size.width * vaultReadinessProgress)
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

                Text(item.isComplete ? "READY" : "ADD NOW")
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
        return count == 1 ? "1 document ready" : "\(count) documents ready"
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
                                "Last reviewed \(vaultRelativeDateText(from: document.updatedAt))",
                                systemImage: "clock"
                            )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            vaultDocumentMetaLabel(
                                "Added \(DateFormatter.rediM8MonthYear.string(from: document.createdAt))",
                                systemImage: "calendar"
                            )
                            vaultDocumentMetaLabel(
                                "Last reviewed \(vaultRelativeDateText(from: document.updatedAt))",
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

    private func openResponderAccess() async {
        do {
            let emergencyInfo = try await service.accessResponderEmergencyInfo()
            responderAccessItem = VaultResponderAccessItem(
                emergencyInfo: emergencyInfo,
                lastUpdatedText: vaultLastUpdatedLine
            )
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

    private var resolvedDocumentCount: Int {
        service.isUnlocked ? service.state.documents.count : service.metadata.documentCount
    }

    private var resolvedQuickAccessCount: Int {
        service.isUnlocked ? service.quickAccessDocuments.count : service.metadata.quickAccessCount
    }

    private var emergencyCardConfigured: Bool {
        service.isUnlocked ? service.state.emergencyInfo.hasAnyContent : service.metadata.hasEmergencyInfo
    }

    private var responderAccessAvailable: Bool {
        emergencyCardConfigured
    }

    private var vaultStatusTint: Color {
        switch vaultStatusHeadline {
        case "Ready for emergency access":
            return ColorTheme.ready
        case "Secure access required to verify":
            return ColorTheme.textTertiary
        default:
            return ColorTheme.warning
        }
    }

    private var vaultPriorityLine: String {
        if !service.metadata.isIndexed && !service.isUnlocked {
            return "Current priority: Open secure access once so RediM8 can verify emergency records stored on this device."
        }

        if !emergencyCardConfigured {
            return "Current priority: Add emergency card details for responder use."
        }

        if resolvedQuickAccessCount == 0 {
            return "Current priority: Stage identity, medical, insurance, or contact records for priority access."
        }

        if resolvedDocumentCount == 0 {
            return "Current priority: Store at least one critical document offline."
        }

        return "Current priority: Review expiry, identity, and insurance records before the next incident."
    }

    private var vaultLastUpdatedLine: String {
        if let date = service.metadata.lastUpdatedAt {
            return "Last updated: \(vaultRelativeDateText(from: date))."
        }

        if service.metadata.isIndexed || service.isUnlocked {
            return "Last updated: Never."
        }

        return "Last updated: Verify after secure access."
    }

    private var vaultLastUpdatedShortLabel: String {
        guard let date = service.metadata.lastUpdatedAt else {
            return service.metadata.isIndexed || service.isUnlocked ? "Never" : "Verify"
        }

        let days = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
        if days <= 0 {
            return "Today"
        }
        if days == 1 {
            return "1d ago"
        }
        return "\(days)d ago"
    }

    private var vaultLastUpdatedMetricDetail: String {
        service.metadata.lastUpdatedAt == nil && !(service.metadata.isIndexed || service.isUnlocked)
            ? "Check after secure access"
            : "Freshness of the last vault change"
    }

    private var vaultLastUpdatedTint: Color {
        service.metadata.lastUpdatedAt == nil ? ColorTheme.textTertiary : ColorTheme.ready
    }

    private var documentsStatusValue: String {
        if !service.metadata.isIndexed && !service.isUnlocked {
            return "Verify"
        }
        return resolvedDocumentCount == 0 ? "None stored" : "\(resolvedDocumentCount) stored"
    }

    private var documentsMetricDetail: String {
        if !service.metadata.isIndexed && !service.isUnlocked {
            return "Open secure access to confirm"
        }
        return resolvedDocumentCount == 0 ? "No critical documents staged" : "Critical records stored locally"
    }

    private var documentsStatusTint: Color {
        resolvedDocumentCount == 0 ? ColorTheme.warning : ColorTheme.textTertiary
    }

    private var priorityAccessStatusValue: String {
        if !service.metadata.isIndexed && !service.isUnlocked {
            return "Verify"
        }
        return resolvedQuickAccessCount == 0 ? "None ready" : "\(resolvedQuickAccessCount) ready"
    }

    private var priorityAccessMetricDetail: String {
        if !service.metadata.isIndexed && !service.isUnlocked {
            return "Check after secure access"
        }
        return resolvedQuickAccessCount == 0
            ? "Nothing staged for first access"
            : "Appears first during evacuation"
    }

    private var priorityAccessStatusTint: Color {
        resolvedQuickAccessCount == 0 ? ColorTheme.warning : ColorTheme.ready
    }

    private var emergencyCardStatusValue: String {
        if !service.metadata.isIndexed && !service.isUnlocked {
            return "Verify"
        }
        return emergencyCardConfigured ? "Configured" : "Required"
    }

    private var emergencyCardMetricDetail: String {
        if !service.metadata.isIndexed && !service.isUnlocked {
            return "Check after secure access"
        }
        return emergencyCardConfigured
            ? "Responder info available"
            : "Medical and contact summary missing"
    }

    private var emergencyCardStatusTint: Color {
        emergencyCardConfigured ? ColorTheme.ready : ColorTheme.warning
    }

    private var vaultRailStatusValue: String {
        switch vaultStatusHeadline {
        case "Ready for emergency access":
            return "Ready"
        case "Secure access required to verify":
            return "Verify"
        default:
            return "Needs Setup"
        }
    }

    private var vaultRailStatusTone: OperationalStatusTone {
        switch vaultStatusHeadline {
        case "Ready for emergency access":
            return .ready
        case "Secure access required to verify":
            return .neutral
        default:
            return .caution
        }
    }

    private var documentsRailValue: String {
        if !service.metadata.isIndexed && !service.isUnlocked {
            return "Verify"
        }
        return resolvedDocumentCount == 0 ? "None" : "\(resolvedDocumentCount) Stored"
    }

    private var documentsRailTone: OperationalStatusTone {
        resolvedDocumentCount == 0 ? .caution : .info
    }

    private var emergencyCardRailValue: String {
        if !service.metadata.isIndexed && !service.isUnlocked {
            return "Verify"
        }
        return emergencyCardConfigured ? "Configured" : "Required"
    }

    private var emergencyCardRailTone: OperationalStatusTone {
        emergencyCardConfigured ? .ready : .caution
    }

    private var priorityAccessRailValue: String {
        if !service.metadata.isIndexed && !service.isUnlocked {
            return "Verify"
        }
        return resolvedQuickAccessCount == 0 ? "None Ready" : "\(resolvedQuickAccessCount) Ready"
    }

    private var priorityAccessRailTone: OperationalStatusTone {
        resolvedQuickAccessCount == 0 ? .caution : .ready
    }

    private func securityBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(ColorTheme.textTertiary)
                .frame(width: 6, height: 6)
                .padding(.top, 7)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func vaultRelativeDateText(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let text = formatter.localizedString(for: date, relativeTo: .now)
        return text == "now" ? "just now" : text
    }
}

struct EmergencyDocumentsQuickView: View {
    @ObservedObject var service: DocumentVaultService
    @Environment(\.dismiss) private var dismiss
    @State private var notice: VaultNotice?
    @State private var previewItem: VaultPreviewItem?
    @State private var responderAccessItem: VaultResponderAccessItem?

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
                        PanelCard(title: "Emergency Card", subtitle: "Responder-friendly summary") {
                            VStack(alignment: .leading, spacing: 10) {
                                emergencyLine("Blood Type", value: service.state.emergencyInfo.bloodType)
                                emergencyLine("Allergies", value: service.state.emergencyInfo.allergies)
                                emergencyLine("Medications", value: service.state.emergencyInfo.medications)
                                emergencyLine("Contacts", value: service.state.emergencyInfo.emergencyContacts)
                                emergencyLine("Medical Notes", value: service.state.emergencyInfo.medicalNotes)
                            }
                        }

                        PanelCard(title: "Priority Documents", subtitle: "Identity, insurance, medical, and contacts first") {
                            if service.quickAccessDocuments.isEmpty {
                                Text("No priority-access vault documents are staged yet.")
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
                        PanelCard(title: "Secure Access", subtitle: "Use responder access for emergency info only, or unlock the full vault.") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("RediM8 keeps these records encrypted locally until device ownership is confirmed.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if service.metadata.hasEmergencyInfo {
                                    Button("Access Responder Card") {
                                        Task { await openResponderAccess() }
                                    }
                                    .buttonStyle(PrimaryActionButtonStyle())
                                }

                                Button("Access Documents") {
                                    Task { await unlockEmergencyDocuments() }
                                }
                                .buttonStyle(SecondaryActionButtonStyle())
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
            .sheet(item: $responderAccessItem) { item in
                NavigationStack {
                    VaultResponderAccessView(item: item)
                }
                .rediSheetPresentation()
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

    private func openResponderAccess() async {
        do {
            let emergencyInfo = try await service.accessResponderEmergencyInfo()
            responderAccessItem = VaultResponderAccessItem(
                emergencyInfo: emergencyInfo,
                lastUpdatedText: {
                    if let date = service.metadata.lastUpdatedAt {
                        return "Last updated \(vaultRelativeDateText(from: date))."
                    }
                    return "Last updated: Never."
                }()
            )
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

    private func vaultRelativeDateText(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let text = formatter.localizedString(for: date, relativeTo: .now)
        return text == "now" ? "just now" : text
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

private struct VaultResponderAccessItem: Identifiable {
    let id = UUID()
    let emergencyInfo: EmergencyInfoCard
    let lastUpdatedText: String
}

private struct VaultResponderAccessView: View {
    let item: VaultResponderAccessItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ModeHeroCard(
                    eyebrow: "Responder Access",
                    title: "Emergency Card",
                    subtitle: "Emergency info only. The full document list remains locked.",
                    iconName: "medical",
                    accent: ColorTheme.ready
                ) {
                    TrustPillGroup(items: [
                        TrustPillItem(title: "Emergency info only", tone: .neutral),
                        TrustPillItem(title: "Offline ready", tone: .neutral),
                        TrustPillItem(title: "Full vault remains locked", tone: .neutral)
                    ])
                }

                PanelCard(title: "Responder Summary", subtitle: item.lastUpdatedText) {
                    VStack(alignment: .leading, spacing: 10) {
                        responderLine("Blood Type", value: item.emergencyInfo.bloodType)
                        responderLine("Allergies", value: item.emergencyInfo.allergies)
                        responderLine("Medications", value: item.emergencyInfo.medications)
                        responderLine("Contacts", value: item.emergencyInfo.emergencyContacts)
                        responderLine("Medical Notes", value: item.emergencyInfo.medicalNotes)
                    }
                }

                PanelCard(title: "Use This For", subtitle: "Share only what is needed in the moment.") {
                    VStack(alignment: .leading, spacing: 8) {
                        securityBulletLine("Medical handoff when you cannot communicate clearly")
                        securityBulletLine("Identity and responder support while the full vault stays locked")
                        securityBulletLine("Fast access when signal, paper copies, or home access are unavailable")
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Responder Access")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private func responderLine(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)
            Text(value.nilIfBlank ?? "Not set")
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)
        }
    }

    private func securityBulletLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(ColorTheme.ready)
                .frame(width: 6, height: 6)
                .padding(.top, 7)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
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
