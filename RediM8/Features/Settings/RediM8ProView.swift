import SwiftUI

struct RediM8ProView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject var storeKitService: StoreKitService
    private let catalog = RediM8MonetizationCatalog.launch
    private let emergencyUnlockState: EmergencyUnlockState

    @State private var purchaseError: String?
    @State private var isShowingError = false
    @State private var hasEntered = false
    @State private var isPulsingAnnualOffer = false

    init(storeKitService: StoreKitService, emergencyUnlockState: EmergencyUnlockState = .inactive) {
        self.storeKitService = storeKitService
        self.emergencyUnlockState = emergencyUnlockState
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CinematicBanner("marketing_coast_storm", height: 200)

                heroCard
                accessCard
                featuresCard
                footerNote
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
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
        .alert("Purchase Error", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseError ?? "An unknown error occurred.")
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
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 10)
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
                    iconSize: 28,
                    titleFont: .system(size: 14, weight: .black),
                    titleColor: Color.white.opacity(0.92)
                )

                Text("PRO")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.42), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    private var heroCard: some View {
        PanelCard(
            backgroundAssetName: heroBackgroundAssetName,
            backgroundImageOffset: heroBackgroundImageOffset,
            surfaceImageOpacity: 0.88,
            surfaceImageBrightness: -0.06,
            surfaceAtmosphere: Color.clear,
            surfaceEdgeColor: ColorTheme.divider,
            surfaceShadowColor: ColorTheme.shadow.opacity(0.18)
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("REDIM8 PRO")
                    .font(RediTypography.metadata)
                    .foregroundStyle(ColorTheme.textTertiary)

                Text("Prepared when networks fail.")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(ColorTheme.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Offline AI, survival maps, and advanced planning while core safety stays free.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        pricingSummaryPill(
                            title: "Month",
                            value: catalog.monthlyOffer.shortPriceText,
                            tint: ColorTheme.textTertiary,
                            backgroundAssetName: offerBackgroundAssetName(for: catalog.monthlyOffer)
                        )
                        pricingSummaryPill(
                            title: "Year",
                            value: catalog.annualOffer.shortPriceText,
                            tint: ColorTheme.textTertiary,
                            backgroundAssetName: offerBackgroundAssetName(for: catalog.annualOffer)
                        )
                        pricingSummaryPill(
                            title: "Lifetime",
                            value: catalog.lifetimeOffer.shortPriceText,
                            tint: ColorTheme.textTertiary,
                            backgroundAssetName: offerBackgroundAssetName(for: catalog.lifetimeOffer)
                        )
                    }

                    VStack(spacing: 10) {
                        pricingSummaryPill(
                            title: "Month",
                            value: catalog.monthlyOffer.shortPriceText,
                            tint: ColorTheme.textTertiary,
                            backgroundAssetName: offerBackgroundAssetName(for: catalog.monthlyOffer)
                        )
                        pricingSummaryPill(
                            title: "Year",
                            value: catalog.annualOffer.shortPriceText,
                            tint: ColorTheme.textTertiary,
                            backgroundAssetName: offerBackgroundAssetName(for: catalog.annualOffer)
                        )
                        pricingSummaryPill(
                            title: "Lifetime",
                            value: catalog.lifetimeOffer.shortPriceText,
                            tint: ColorTheme.textTertiary,
                            backgroundAssetName: offerBackgroundAssetName(for: catalog.lifetimeOffer)
                        )
                    }
                }

                if emergencyUnlockState.isVisible {
                    emergencyUnlockBanner
                }

                TrustPillGroup(items: heroTrustItems)
            }
        }
    }

    private var accessCard: some View {
        PanelCard(
            title: "Choose Access",
            subtitle: "Pick the plan that suits your household. Core safety features stay free.",
            backgroundAssetName: "marketing_command_table",
            backgroundImageOffset: CGSize(width: 22, height: 0),
            surfaceImageOpacity: 0.9,
            surfaceImageBrightness: -0.05,
            surfaceAtmosphere: Color.clear,
            surfaceEdgeColor: ColorTheme.dividerStrong,
            surfaceShadowColor: ColorTheme.shadow.opacity(0.16)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                offerCard(catalog.recommendedOffer, isPrimary: true)
                offerCard(catalog.monthlyOffer, isPrimary: false)
                offerCard(catalog.lifetimeOffer, isPrimary: false)

                Button("Continue Free") {
                    dismiss()
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button("Restore Purchases") {
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
            Text("Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period. Your Apple ID account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel subscriptions in your App Store account settings.")
                .font(.caption2.weight(.medium))
                .foregroundStyle(ColorTheme.textFaint)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Link("Privacy Policy", destination: URL(string: "https://redim8.com.au/privacy")!)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ColorTheme.textTertiary)

                Link("Terms of Use", destination: URL(string: "https://redim8.com.au/terms")!)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ColorTheme.textTertiary)

                Link("Manage Subscription", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ColorTheme.textTertiary)
            }
        }
        .padding(.top, 4)
    }

    private var featuresCard: some View {
        PanelCard(
            title: "What Pro Adds",
            subtitle: "Extra depth for planning and offline use, while core emergency tools remain available for everyone.",
            backgroundAssetName: "paywall_blackout",
            backgroundImageOffset: CGSize(width: 18, height: 0),
            surfaceImageOpacity: 0.9,
            surfaceImageBrightness: -0.05,
            surfaceAtmosphere: Color.clear,
            surfaceEdgeColor: ColorTheme.dividerStrong,
            surfaceShadowColor: ColorTheme.shadow.opacity(0.16)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(proFeatures) { feature in
                    featureRow(feature)
                }

                Divider()
                    .background(ColorTheme.divider)

                paywallTrustRow(
                    title: "Always-free core safety",
                    message: catalog.alwaysFreePromise,
                    systemImage: "checkmark.shield.fill",
                    tint: ColorTheme.ready,
                    backgroundAssetName: "community_shelter_hub"
                )

                paywallTrustRow(
                    title: emergencyUnlockState.isVisible ? emergencyUnlockState.calloutTitle : "Emergency unlock for real incidents",
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.easeInOut(duration: 0.34)) {
                isPulsingAnnualOffer = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.26)) {
                isPulsingAnnualOffer = false
            }
        }
    }

    private var footerNote: some View {
        Text("Prices shown in AUD. Payment is charged to your Apple ID account at confirmation of purchase.")
            .font(.footnote.weight(.medium))
            .foregroundStyle(ColorTheme.textFaint)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }

    private var heroBackgroundAssetName: String {
        emergencyUnlockState.isActive ? "paywall_fire" : "paywall_storm"
    }

    private var heroBackgroundImageOffset: CGSize {
        emergencyUnlockState.isActive ? CGSize(width: 26, height: 0) : CGSize(width: 18, height: 0)
    }

    private var heroTrustItems: [TrustPillItem] {
        [
            TrustPillItem(title: "Core safety stays free", tone: .verified),
            TrustPillItem(title: "Offline-first upgrade", tone: .info),
            TrustPillItem(title: "Emergency unlock aware", tone: .caution)
        ]
    }

    private var annualSavingsSummary: String {
        let monthlyYearlyCost = NSDecimalNumber(decimal: catalog.monthlyOffer.priceAUD).doubleValue * 12
        let annualCost = NSDecimalNumber(decimal: catalog.annualOffer.priceAUD).doubleValue
        guard monthlyYearlyCost > 0 else { return "Best value" }

        let savingsPercent = max(0, Int(((monthlyYearlyCost - annualCost) / monthlyYearlyCost * 100).rounded()))
        return "Save \(savingsPercent)% vs monthly"
    }

    private var proFeatures: [ProFeature] {
        [
            ProFeature(
                title: "Offline assistant",
                detail: "Retrieval-first survival summaries when signal is weak or unavailable.",
                systemImage: "sparkles",
                tint: ColorTheme.textTertiary,
                backgroundAssetName: "paywall_blackout",
                backgroundImageOffset: CGSize(width: 14, height: 0)
            ),
            ProFeature(
                title: "Expanded survival maps",
                detail: "More tactical map coverage and fallback navigation depth when regular coverage fails.",
                systemImage: "map.fill",
                tint: ColorTheme.textTertiary,
                backgroundAssetName: "map_remote_track",
                backgroundImageOffset: CGSize(width: 10, height: 0)
            ),
            ProFeature(
                title: "Advanced planning tools",
                detail: "Richer household planning, exports, and readiness workflows across the app.",
                systemImage: "checkmark.square.fill",
                tint: ColorTheme.textTertiary,
                backgroundAssetName: "marketing_command_table",
                backgroundImageOffset: CGSize(width: 16, height: 0)
            )
        ]
    }

    private var emergencyUnlockBanner: some View {
        let accent = emergencyUnlockState.isActive ? ColorTheme.ready : ColorTheme.warning
        let title = emergencyUnlockState.isActive ? "Emergency Unlock Active" : "Emergency Access Ended"

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
        .padding(14)
        .proInsetSurface(
            cornerRadius: 20,
            edgeColor: accent.opacity(0.2),
            shadowColor: ColorTheme.shadow.opacity(0.12),
            tintFill: accent.opacity(0.08),
            backgroundAssetName: emergencyUnlockState.isActive ? "signal_vehicle_link" : "paywall_blackout",
            backgroundImageOffset: CGSize(width: 18, height: 0),
            atmosphere: accent.opacity(0.12)
        )
    }

    private func pricingSummaryPill(
        title: String,
        value: String,
        tint: Color,
        backgroundAssetName: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(RediTypography.metadata)
                .foregroundStyle(ColorTheme.textFaint)

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .proInsetSurface(
            cornerRadius: 18,
            edgeColor: ColorTheme.dividerStrong,
            tintFill: tint.opacity(0.05),
            backgroundAssetName: backgroundAssetName,
            backgroundImageOffset: CGSize(width: 12, height: 0),
            imageOpacity: 0.32,
            atmosphere: tint.opacity(0.12)
        )
    }

    private func offerCard(_ offer: RediM8ProOffer, isPrimary: Bool) -> some View {
        let accent = offerAccent(for: offer)
        let shouldPulse = offer.isRecommended && isPulsingAnnualOffer

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(offer.title)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(ColorTheme.text)

                        if let badge = offer.badge {
                            Text(badge.uppercased())
                                .font(RediTypography.metadata)
                                .foregroundStyle(isPrimary ? Color.black.opacity(0.8) : accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    isPrimary ? AnyShapeStyle(accent.opacity(0.9)) : AnyShapeStyle(accent.opacity(0.12)),
                                    in: Capsule()
                                )
                        }
                    }

                    Text(offer.billingSummary.uppercased())
                        .font(RediTypography.metadata)
                        .foregroundStyle(accent)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(offer.shortPriceText)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(ColorTheme.text)

                    if let priceCallout = priceCallout(for: offer) {
                        Text(priceCallout)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accent.opacity(0.92))
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Text(offer.supportingLine)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ColorTheme.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(offer.detail)
                .font(.footnote.weight(.medium))
                .foregroundStyle(ColorTheme.textMuted)
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
                    .disabled(storeKitService.isLoading)
            } else {
                Button(offer.ctaTitle) { purchase(offer) }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(storeKitService.isLoading)
            }
        }
        .padding(18)
        .scaleEffect(shouldPulse ? 1.018 : 1)
        .proInsetSurface(
            cornerRadius: 24,
            edgeColor: accent.opacity(isPrimary ? 0.26 : 0.16),
            shadowColor: ColorTheme.shadow.opacity(0.14),
            tintFill: accent.opacity(isPrimary ? 0.08 : 0.04),
            backgroundAssetName: offerBackgroundAssetName(for: offer),
            backgroundImageOffset: offerBackgroundImageOffset(for: offer),
            atmosphere: accent.opacity(isPrimary ? 0.16 : 0.1)
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.34), value: shouldPulse)
    }

    private func priceCallout(for offer: RediM8ProOffer) -> String? {
        switch offer.interval {
        case .monthly:
            nil
        case .annual:
            annualSavingsSummary
        case .lifetime:
            "Limited launch offer"
        }
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
        .padding(14)
        .proInsetSurface(
            cornerRadius: 20,
            edgeColor: ColorTheme.dividerStrong,
            tintFill: feature.tint.opacity(0.04),
            backgroundAssetName: feature.backgroundAssetName,
            backgroundImageOffset: feature.backgroundImageOffset,
            atmosphere: feature.tint.opacity(0.1)
        )
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
        .padding(14)
        .proInsetSurface(
            cornerRadius: 20,
            edgeColor: tint.opacity(0.12),
            shadowColor: ColorTheme.shadow.opacity(0.1),
            tintFill: tint.opacity(0.05),
            backgroundAssetName: backgroundAssetName,
            backgroundImageOffset: CGSize(width: 16, height: 0),
            atmosphere: tint.opacity(0.1)
        )
    }

    private func offerAccent(for offer: RediM8ProOffer) -> Color {
        switch offer.interval {
        case .monthly:
            ColorTheme.textTertiary
        case .annual:
            ColorTheme.textTertiary
        case .lifetime:
            ColorTheme.textTertiary
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
