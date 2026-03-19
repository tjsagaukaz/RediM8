import SwiftUI

struct RediM8ProView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject var storeKitService: StoreKitService
    private let catalog = RediM8MonetizationCatalog.launch
    private let emergencyUnlockState: EmergencyUnlockState

    @State private var purchaseError: String?
    @State private var isShowingError = false
    @State private var hasEntered = false

    init(storeKitService: StoreKitService, emergencyUnlockState: EmergencyUnlockState = .inactive) {
        self.storeKitService = storeKitService
        self.emergencyUnlockState = emergencyUnlockState
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CinematicBanner("marketing_coast_storm", height: 156)

                heroCard
                accessCard
                featuresCard
                footerNote
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .offset(y: hasEntered ? 0 : 40)
            .opacity(hasEntered ? 1 : 0.01)
        }
        .scrollIndicators(.hidden)
        .background(ColorTheme.background.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            topBarContainer
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: startPaywallPresentation)
        .task { await storeKitService.loadProducts() }
        .animation(
            reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.9),
            value: hasEntered
        )
        .alert(L10n.tr("paywall.alert.purchase_error.title", "Purchase Error"), isPresented: $isShowingError) {
            Button(L10n.tr("common.ok", "OK"), role: .cancel) {}
        } message: {
            Text(purchaseError ?? L10n.tr("paywall.alert.purchase_error.unknown", "An unknown error occurred."))
        }
    }

    private func purchase(_ offer: RediM8ProOffer) {
        Task {
            do {
                try await storeKitService.purchase(offer.interval.productID)
                dismiss()
            } catch let error as PurchaseError where error == .purchaseCancelled {
                // User cancelled — no error needed
            } catch {
                purchaseError = error.localizedDescription
                isShowingError = true
            }
        }
    }

    private var topBarContainer: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)
        }
        .background(
            LinearGradient(
                colors: [
                    ColorTheme.background.opacity(0.98),
                    ColorTheme.background.opacity(0.9),
                    ColorTheme.background.opacity(0.58),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                RediM8Wordmark(
                    iconSize: 24,
                    titleFont: .system(size: 13, weight: .black),
                    titleColor: Color.white.opacity(0.92)
                )

                Text(L10n.tr("paywall.brand.badge", "PRO"))
                    .font(.caption2.weight(.black))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08), in: Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.34), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.42), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.tr("common.close", "Close"))
            .accessibilityHint(L10n.tr("paywall.close.hint", "Dismisses the RediM8 Pro plans screen."))
        }
    }

    private var heroCard: some View {
        PanelCard(
            backgroundAssetName: emergencyUnlockState.isActive ? "paywall_fire" : "paywall_storm",
            backgroundImageOffset: emergencyUnlockState.isActive ? CGSize(width: 26, height: 0) : CGSize(width: 18, height: 0),
            surfaceImageOpacity: 0.88,
            surfaceImageBrightness: -0.06,
            surfaceAtmosphere: Color.clear,
            surfaceEdgeColor: ColorTheme.divider,
            surfaceShadowColor: ColorTheme.shadow.opacity(0.18)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.tr("paywall.brand.title", "REDIM8 PRO"))
                    .font(RediTypography.metadata)
                    .foregroundStyle(ColorTheme.textTertiary)

                Text(L10n.tr("paywall.hero.title", "Prepared when networks fail."))
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(ColorTheme.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.tr(
                    "paywall.hero.subtitle",
                    "Offline assistance, expanded survival maps, and deeper planning tools. Core safety remains free."
                ))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                if emergencyUnlockState.isVisible {
                    emergencyUnlockBanner
                }
            }
        }
    }

    private var accessCard: some View {
        PanelCard(
            title: L10n.tr("paywall.access.title", "Choose Your Access"),
            subtitle: L10n.tr(
                "paywall.access.subtitle",
                "Select the level of readiness that fits your household."
            ),
            backgroundAssetName: "marketing_command_table",
            backgroundImageOffset: CGSize(width: 22, height: 0),
            surfaceImageOpacity: 0.9,
            surfaceImageBrightness: -0.05,
            surfaceAtmosphere: Color.clear,
            surfaceEdgeColor: ColorTheme.dividerStrong,
            surfaceShadowColor: ColorTheme.shadow.opacity(0.16)
        ) {
            VStack(alignment: .leading, spacing: 14) {
                accessSectionLabel(L10n.tr("paywall.access.section.recommended", "Recommended Access"))
                offerCard(catalog.recommendedOffer, isPrimary: true)

                accessSectionLabel(L10n.tr("paywall.access.section.other", "Other Access Options"))
                offerCard(catalog.monthlyOffer, isPrimary: false)
                offerCard(catalog.lifetimeOffer, isPrimary: false)

                if !storeKitService.hasLoadedAllProducts {
                    Text(storeKitService.errorMessage ?? L10n.tr(
                        "paywall.access.pricing_loading",
                        "Live pricing appears from the App Store before purchase."
                    ))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ColorTheme.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(L10n.tr("paywall.access.continue_free", "Continue with Free Core Safety")) {
                    dismiss()
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button(L10n.tr("paywall.access.restore_purchases", "Restore Purchases")) {
                    Task { await storeKitService.restorePurchases() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ColorTheme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)

                subscriptionTerms
            }
        }
    }

    private var subscriptionTerms: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr(
                "paywall.terms.subscription_copy",
                "Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period. Your Apple ID account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel subscriptions in your App Store account settings."
            ))
                .font(.caption2.weight(.medium))
                .foregroundStyle(ColorTheme.textFaint)
                .fixedSize(horizontal: false, vertical: true)

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        Link(L10n.tr("paywall.terms.privacy_policy", "Privacy Policy"), destination: URL(string: "https://redim8.com.au/privacy")!)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(ColorTheme.textTertiary)

                        Link(L10n.tr("paywall.terms.terms_of_use", "Terms of Use"), destination: URL(string: "https://redim8.com.au/terms")!)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(ColorTheme.textTertiary)

                        Link(L10n.tr("paywall.terms.manage_subscription", "Manage Subscription"), destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(ColorTheme.textTertiary)
                    }
                } else {
                    HStack(spacing: 12) {
                        Link(L10n.tr("paywall.terms.privacy_policy", "Privacy Policy"), destination: URL(string: "https://redim8.com.au/privacy")!)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(ColorTheme.textTertiary)

                        Link(L10n.tr("paywall.terms.terms_of_use", "Terms of Use"), destination: URL(string: "https://redim8.com.au/terms")!)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(ColorTheme.textTertiary)

                        Link(L10n.tr("paywall.terms.manage_subscription", "Manage Subscription"), destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(ColorTheme.textTertiary)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private var featuresCard: some View {
        PanelCard(
            title: L10n.tr("paywall.features.title", "What Pro Adds"),
            subtitle: L10n.tr(
                "paywall.features.subtitle",
                "Three added capability layers for deeper household readiness."
            ),
            backgroundAssetName: "paywall_blackout",
            backgroundImageOffset: CGSize(width: 18, height: 0),
            surfaceImageOpacity: 0.9,
            surfaceImageBrightness: -0.05,
            surfaceAtmosphere: Color.clear,
            surfaceEdgeColor: ColorTheme.dividerStrong,
            surfaceShadowColor: ColorTheme.shadow.opacity(0.16)
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(proFeatures) { feature in
                    featureRow(feature)
                }

                Divider()
                    .background(ColorTheme.divider)

                paywallTrustRow(
                    title: L10n.tr("paywall.trust.always_free.title", "Always-free core safety"),
                    message: catalog.alwaysFreePromise,
                    systemImage: "checkmark.shield.fill",
                    tint: ColorTheme.ready,
                    backgroundAssetName: "community_shelter_hub"
                )

                paywallTrustRow(
                    title: emergencyUnlockState.isVisible
                        ? emergencyUnlockState.calloutTitle
                        : L10n.tr("paywall.trust.emergency_unlock.title", "Emergency unlock during severe official incidents"),
                    message: emergencyUnlockState.isVisible ? emergencyUnlockState.calloutDetail : catalog.emergencyUnlockPromise,
                    systemImage: "bolt.shield.fill",
                    tint: emergencyUnlockState.isActive ? ColorTheme.ready : ColorTheme.warning,
                    backgroundAssetName: emergencyUnlockState.isActive ? "signal_vehicle_link" : "paywall_blackout"
                )
            }
        }
    }

    private func startPaywallPresentation() {
        guard !hasEntered else { return }

        if reduceMotion {
            hasEntered = true
            return
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
            hasEntered = true
        }
    }

    private var footerNote: some View {
        Text(L10n.tr(
            "paywall.footer.pricing_note",
            "Prices shown in AUD. Payment is charged to your Apple ID account at confirmation of purchase."
        ))
            .font(.footnote.weight(.medium))
            .foregroundStyle(ColorTheme.textFaint)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }

    private var proFeatures: [ProFeature] {
        [
            ProFeature(
                title: L10n.tr("paywall.feature.assistant.title", "Offline assistant"),
                detail: L10n.tr("paywall.feature.assistant.detail", "Retrieval-first survival summaries when signal is weak or unavailable."),
                systemImage: "sparkles",
                tint: ColorTheme.textTertiary,
                backgroundAssetName: "paywall_blackout",
                backgroundImageOffset: CGSize(width: 14, height: 0)
            ),
            ProFeature(
                title: L10n.tr("paywall.feature.maps.title", "Expanded survival maps"),
                detail: L10n.tr("paywall.feature.maps.detail", "Expanded offline map coverage and fallback navigation depth."),
                systemImage: "map.fill",
                tint: ColorTheme.textTertiary,
                backgroundAssetName: "map_remote_track",
                backgroundImageOffset: CGSize(width: 10, height: 0)
            ),
            ProFeature(
                title: L10n.tr("paywall.feature.planning.title", "Advanced planning tools"),
                detail: L10n.tr("paywall.feature.planning.detail", "Deeper household planning, exports, and readiness workflows."),
                systemImage: "checkmark.square.fill",
                tint: ColorTheme.textTertiary,
                backgroundAssetName: "marketing_command_table",
                backgroundImageOffset: CGSize(width: 16, height: 0)
            )
        ]
    }

    private var emergencyUnlockBanner: some View {
        let accent = emergencyUnlockState.isActive ? ColorTheme.ready : ColorTheme.warning
        let title = emergencyUnlockState.isActive
            ? L10n.tr("paywall.emergency_unlock.active_title", "Emergency Unlock Active")
            : L10n.tr("paywall.emergency_unlock.ended_title", "Emergency Access Ended")

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: emergencyUnlockState.isActive ? "bolt.shield.fill" : "clock.badge.exclamationmark.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ColorTheme.text)

                Text(emergencyUnlockState.calloutDetail)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(ColorTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .proInsetSurface(
            cornerRadius: 16,
            edgeColor: accent.opacity(0.2),
            shadowColor: ColorTheme.shadow.opacity(0.12),
            tintFill: accent.opacity(0.08),
            backgroundAssetName: emergencyUnlockState.isActive ? "signal_vehicle_link" : "paywall_blackout",
            backgroundImageOffset: CGSize(width: 18, height: 0),
            atmosphere: accent.opacity(0.12)
        )
    }

    private func offerCard(_ offer: RediM8ProOffer, isPrimary: Bool) -> some View {
        let accent = offerAccent(for: offer)

        return VStack(alignment: .leading, spacing: 12) {
            offerHeader(offer: offer, accent: accent, isPrimary: isPrimary)

            Text(offer.supportingLine)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ColorTheme.text)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(offer.highlights.prefix(isPrimary ? 3 : 2), id: \.self) { highlight in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(accent)
                            .padding(.top, 2)

                        Text(highlight)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ColorTheme.text)
                    }
                }
            }

            if isPrimary {
                Button(offer.ctaTitle) { purchase(offer) }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(!storeKitService.hasLoadedAllProducts || storeKitService.isLoading)
                    .accessibilityHint(L10n.format("paywall.offer.cta.hint", "Purchases the %@ plan.", offer.title))
            } else {
                Button(offer.ctaTitle) { purchase(offer) }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(!storeKitService.hasLoadedAllProducts || storeKitService.isLoading)
                    .accessibilityHint(L10n.format("paywall.offer.cta.hint", "Purchases the %@ plan.", offer.title))
            }
        }
        .padding(16)
        .proInsetSurface(
            cornerRadius: 18,
            edgeColor: accent.opacity(isPrimary ? 0.34 : 0.16),
            shadowColor: ColorTheme.shadow.opacity(0.12),
            tintFill: accent.opacity(isPrimary ? 0.1 : 0.03),
            backgroundAssetName: offerBackgroundAssetName(for: offer),
            backgroundImageOffset: offerBackgroundImageOffset(for: offer),
            atmosphere: accent.opacity(isPrimary ? 0.12 : 0.06)
        )
        .accessibilityElement(children: .contain)
    }

    private func featureRow(_ feature: ProFeature) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(feature.tint.opacity(0.14))
                    .frame(width: 40, height: 40)

                Image(systemName: feature.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(feature.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)

                Text(feature.detail)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(ColorTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .proInsetSurface(
            cornerRadius: 16,
            edgeColor: ColorTheme.dividerStrong,
            tintFill: feature.tint.opacity(0.04),
            backgroundAssetName: feature.backgroundAssetName,
            backgroundImageOffset: feature.backgroundImageOffset,
            atmosphere: feature.tint.opacity(0.1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(feature.title)
        .accessibilityHint(feature.detail)
    }

    private func paywallTrustRow(
        title: String,
        message: String,
        systemImage: String,
        tint: Color,
        backgroundAssetName: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 40, height: 40)

                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)

                Text(message)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(ColorTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .proInsetSurface(
            cornerRadius: 16,
            edgeColor: tint.opacity(0.12),
            shadowColor: ColorTheme.shadow.opacity(0.1),
            tintFill: tint.opacity(0.05),
            backgroundAssetName: backgroundAssetName,
            backgroundImageOffset: CGSize(width: 16, height: 0),
            atmosphere: tint.opacity(0.1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint(message)
    }

    private func displayPrice(for offer: RediM8ProOffer) -> String {
        storeKitService.displayPrice(for: offer.interval.productID) ?? L10n.tr("common.value.unavailable", "—")
    }

    private func priceSupportingText(for offer: RediM8ProOffer) -> String {
        if storeKitService.hasLoadedAllProducts {
            return offer.billingSummary
        }

        return L10n.tr("paywall.price.placeholder", "Price from App Store")
    }

    private func offerAccent(for offer: RediM8ProOffer) -> Color {
        switch offer.interval {
        case .monthly:
            ColorTheme.textTertiary
        case .annual:
            ColorTheme.accent
        case .lifetime:
            ColorTheme.textSecondary
        }
    }

    private func offerBackgroundAssetName(for offer: RediM8ProOffer) -> String {
        switch offer.interval {
        case .monthly:
            "paywall_storm"
        case .annual:
            "paywall_fire"
        case .lifetime:
            "marketing_command_table"
        }
    }

    private func offerBackgroundImageOffset(for offer: RediM8ProOffer) -> CGSize {
        switch offer.interval {
        case .monthly:
            CGSize(width: 18, height: 0)
        case .annual:
            CGSize(width: 28, height: 0)
        case .lifetime:
            CGSize(width: 20, height: 0)
        }
    }

    @ViewBuilder
    private func offerHeader(offer: RediM8ProOffer, accent: Color, isPrimary: Bool) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                offerTitleBlock(offer: offer, accent: accent, isPrimary: isPrimary)
                offerPriceBlock(
                    offer: offer,
                    accent: accent,
                    horizontalAlignment: .leading,
                    textAlignment: .leading
                )
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                offerTitleBlock(offer: offer, accent: accent, isPrimary: isPrimary)
                Spacer(minLength: 0)
                offerPriceBlock(
                    offer: offer,
                    accent: accent,
                    horizontalAlignment: .trailing,
                    textAlignment: .trailing
                )
            }
        }
    }

    private func offerTitleBlock(offer: RediM8ProOffer, accent: Color, isPrimary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(offer.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ColorTheme.text)

                if let badge = offer.badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isPrimary ? Color.black.opacity(0.8) : accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            isPrimary ? AnyShapeStyle(accent.opacity(0.9)) : AnyShapeStyle(accent.opacity(0.12)),
                            in: Capsule()
                        )
                }
            }
        }
    }

    private func offerPriceBlock(
        offer: RediM8ProOffer,
        accent: Color,
        horizontalAlignment: HorizontalAlignment,
        textAlignment: TextAlignment
    ) -> some View {
        VStack(alignment: horizontalAlignment, spacing: 2) {
            Text(displayPrice(for: offer))
                .font(.largeTitle.weight(.black))
                .foregroundStyle(ColorTheme.text)

            Text(priceSupportingText(for: offer))
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent.opacity(0.92))
                .multilineTextAlignment(textAlignment)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func accessSectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(RediTypography.label)
            .tracking(1.2)
            .foregroundStyle(ColorTheme.textTertiary)
    }
}

private struct ProFeature: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    let backgroundAssetName: String
    let backgroundImageOffset: CGSize
}

private struct ProInsetSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let edgeColor: Color
    let shadowColor: Color
    let tintFill: Color
    let backgroundAssetName: String?
    let backgroundImageOffset: CGSize
    let imageOpacity: Double
    let atmosphere: Color?

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    PremiumSurfaceBackground(
                        cornerRadius: cornerRadius,
                        backgroundAssetName: backgroundAssetName,
                        backgroundImageOffset: backgroundImageOffset,
                        atmosphere: atmosphere ?? Color.clear,
                        imageOpacity: imageOpacity,
                        imageTopShadeOpacity: backgroundAssetName == nil ? 0.28 : 0.36,
                        imageBottomShadeOpacity: backgroundAssetName == nil ? 0.76 : 0.84,
                        brightness: backgroundAssetName == nil ? -0.04 : -0.08
                    )

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tintFill)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.03),
                                    Color.clear,
                                    Color.black.opacity(0.08)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .modifier(
                PremiumSurfaceChrome(
                    cornerRadius: cornerRadius,
                    edgeColor: edgeColor,
                    shadowColor: shadowColor
                )
            )
    }
}

private extension View {
    func proInsetSurface(
        cornerRadius: CGFloat,
        edgeColor: Color = ColorTheme.dividerStrong,
        shadowColor: Color = ColorTheme.shadow.opacity(0.14),
        tintFill: Color = .clear,
        backgroundAssetName: String? = nil,
        backgroundImageOffset: CGSize = .zero,
        imageOpacity: Double = 1,
        atmosphere: Color? = nil
    ) -> some View {
        modifier(
            ProInsetSurfaceModifier(
                cornerRadius: cornerRadius,
                edgeColor: edgeColor,
                shadowColor: shadowColor,
                tintFill: tintFill,
                backgroundAssetName: backgroundAssetName,
                backgroundImageOffset: backgroundImageOffset,
                imageOpacity: imageOpacity,
                atmosphere: atmosphere
            )
        )
    }
}
