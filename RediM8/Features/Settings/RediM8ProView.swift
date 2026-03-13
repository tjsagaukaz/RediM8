import SwiftUI
import UIKit

struct RediM8ProView: View {
    @Environment(\.dismiss) private var dismiss

    private let catalog = RediM8MonetizationCatalog.launch
    private let emergencyUnlockState: EmergencyUnlockState
    private let sceneRotationTimer = Timer.publish(every: 11, on: .main, in: .common).autoconnect()
    private let sceneTransitionDuration = 2.4
    private let backdropMotionDuration = 24.0

    @State private var selectedOffer: RediM8ProOffer?
    @State private var isShowingPricingAlert = false
    @State private var activeSceneIndex = 0
    @State private var animateBackdrop = false

    init(emergencyUnlockState: EmergencyUnlockState = .inactive) {
        self.emergencyUnlockState = emergencyUnlockState
    }

    var body: some View {
        GeometryReader { proxy in
            let safeTop = max(proxy.safeAreaInsets.top, 12)
            let safeBottom = max(proxy.safeAreaInsets.bottom, 16)
            let heroHeight = max(proxy.size.height * 0.58, 360)

            ZStack(alignment: .top) {
                ColorTheme.background.ignoresSafeArea()

                cinematicBackdrop(height: heroHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                VStack(spacing: 0) {
                    Spacer(minLength: max(proxy.size.height * 0.36, 230))

                    paywallCard
                        .padding(.horizontal, 18)
                        .padding(.bottom, safeBottom)
                }

                topBar
                    .padding(.horizontal, 18)
                    .padding(.top, safeTop)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            animateBackdrop = true
        }
        .onReceive(sceneRotationTimer) { _ in
            guard PaywallScene.allCases.count > 1 else { return }
            withAnimation(.easeInOut(duration: sceneTransitionDuration)) {
                activeSceneIndex = (activeSceneIndex + 1) % PaywallScene.allCases.count
            }
        }
        .alert("Pricing Preview", isPresented: $isShowingPricingAlert, presenting: selectedOffer) { _ in
            Button("OK", role: .cancel) {}
        } message: { offer in
            if emergencyUnlockState.isActive {
                Text("\(offer.title) normally costs \(offer.priceText), but Emergency Unlock is active right now, so Pro tools are temporarily available without billing.")
            } else {
                Text("\(offer.title) is set to \(offer.priceText). Billing is not active in this build yet, so this screen is a launch pricing preview only.")
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                RediM8Wordmark(
                    iconSize: 28,
                    titleFont: .system(size: 14, weight: .black),
                    titleColor: Color.white.opacity(0.9)
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
        }
    }

    private func cinematicBackdrop(height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            ForEach(Array(PaywallScene.allCases.enumerated()), id: \.offset) { index, scene in
                cinematicScene(scene)
                    .opacity(activeSceneIndex == index ? 1 : 0)
                    .animation(.easeInOut(duration: sceneTransitionDuration), value: activeSceneIndex)
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.28),
                    Color.black.opacity(0.64),
                    Color.black.opacity(0.88),
                    ColorTheme.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.46)
                ],
                center: .center,
                startRadius: 80,
                endRadius: 740
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.34),
                    Color.clear,
                    Color.black.opacity(0.18)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            HStack(spacing: 8) {
                ForEach(Array(PaywallScene.allCases.enumerated()), id: \.offset) { index, _ in
                    Capsule()
                        .fill(activeSceneIndex == index ? Color.white.opacity(0.95) : Color.white.opacity(0.28))
                        .frame(width: activeSceneIndex == index ? 24 : 8, height: 5)
                        .animation(.spring(response: 0.55, dampingFraction: 0.84), value: activeSceneIndex)
                }
            }
            .padding(.bottom, 28)
        }
        .frame(height: height)
        .clipped()
    }

    private func cinematicScene(_ scene: PaywallScene) -> some View {
        ZStack {
            if let image = UIImage(named: scene.assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .saturation(0.94)
                    .contrast(1.04)
                    .brightness(-0.03)
            } else {
                fallbackScene(for: scene)
            }
        }
        .overlay {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.16),
                        Color.clear,
                        Color.black.opacity(0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.08),
                        Color.black.opacity(0.28)
                    ],
                    center: .center,
                    startRadius: 140,
                    endRadius: 760
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(animateBackdrop ? scene.activeScale : scene.idleScale)
        .offset(
            x: animateBackdrop ? scene.activeOffset.width : scene.idleOffset.width,
            y: animateBackdrop ? scene.activeOffset.height : scene.idleOffset.height
        )
        .animation(.easeInOut(duration: backdropMotionDuration).repeatForever(autoreverses: true), value: animateBackdrop)
    }

    private func fallbackScene(for scene: PaywallScene) -> some View {
        ZStack {
            LinearGradient(
                colors: scene.baseColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            scene.tint
                .opacity(0.3)
                .blur(radius: 140)
                .frame(width: 280, height: 280)
                .offset(x: scene.glowOffset.width, y: scene.glowOffset.height)

            scene.tint
                .opacity(0.14)
                .blur(radius: 120)
                .frame(width: 320, height: 220)
                .offset(x: -scene.glowOffset.width * 0.6, y: -scene.glowOffset.height * 0.4)

            LinearGradient(
                colors: [Color.white.opacity(0.22), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .rotationEffect(scene.highlightAngle)
            .blur(radius: 36)
            .offset(x: scene.highlightOffset.width, y: scene.highlightOffset.height)

            Image(systemName: scene.symbolName)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.white.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 1.2)
                .offset(x: scene.symbolOffset.width, y: scene.symbolOffset.height)
        }
    }

    private var activeScene: PaywallScene {
        PaywallScene.allCases[activeSceneIndex]
    }

    private var paywallAccent: Color {
        activeScene.tint
    }

    private var paywallCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            if emergencyUnlockState.isVisible {
                emergencyUnlockBanner
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("INFRASTRUCTURE FAILURE UPGRADE")
                    .font(RediTypography.metadata)
                    .foregroundStyle(paywallAccent)

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RediM8 Pro")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(ColorTheme.text)

                        Text("Keep more of your preparedness operating system working when normal coverage, context, and time are under pressure.")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(ColorTheme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    if let badge = catalog.recommendedOffer.badge {
                        Text(badge.uppercased())
                            .font(RediTypography.caption)
                            .foregroundStyle(Color.black.opacity(0.82))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(paywallAccent, in: Capsule())
                    }
                }

                TrustPillGroup(items: [
                    TrustPillItem(title: "Core safety stays free", tone: .verified),
                    TrustPillItem(title: "Offline-first upgrade", tone: .info),
                    TrustPillItem(title: "Emergency unlock aware", tone: .caution)
                ])
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("Why households upgrade")
                    .font(RediTypography.sectionTitle)
                    .foregroundStyle(ColorTheme.text)

                LazyVGrid(columns: paywallOutcomeColumns, spacing: 12) {
                    ForEach(proOutcomes) { outcome in
                        paywallOutcomeCard(outcome)
                    }
                }
            }

            paywallSpotlightCard

            VStack(alignment: .leading, spacing: 12) {
                Text("Choose access")
                    .font(RediTypography.sectionTitle)
                    .foregroundStyle(ColorTheme.text)

                actionButton(
                    title: "Upgrade to Pro",
                    subtitle: "\(catalog.recommendedOffer.billingSummary) • \(catalog.recommendedOffer.supportingLine)",
                    trailingText: "\(catalog.recommendedOffer.shortPriceText)/yr",
                    badge: catalog.recommendedOffer.badge,
                    style: .primary
                ) {
                    selectedOffer = catalog.recommendedOffer
                    isShowingPricingAlert = true
                }

                actionButton(
                    title: "Lifetime Access",
                    subtitle: "\(catalog.lifetimeOffer.billingSummary) • \(catalog.lifetimeOffer.supportingLine)",
                    trailingText: "\(catalog.lifetimeOffer.shortPriceText) once",
                    badge: catalog.lifetimeOffer.badge,
                    style: .highlight
                ) {
                    selectedOffer = catalog.lifetimeOffer
                    isShowingPricingAlert = true
                }

                actionButton(
                    title: "Continue Free",
                    subtitle: "Emergency Mode, official alerts, offline maps, Signal, and core guides stay available.",
                    trailingText: nil,
                    badge: nil,
                    style: .secondary
                ) {
                    dismiss()
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                paywallTrustRow(
                    title: "Always-free core safety",
                    message: catalog.alwaysFreePromise,
                    systemImage: "checkmark.shield.fill",
                    tint: ColorTheme.ready
                )
                paywallTrustRow(
                    title: emergencyUnlockState.isVisible ? emergencyUnlockState.calloutTitle : "Emergency unlock for real incidents",
                    message: emergencyUnlockState.isVisible ? emergencyUnlockState.calloutDetail : catalog.emergencyUnlockPromise,
                    systemImage: "bolt.shield.fill",
                    tint: emergencyUnlockState.isActive ? ColorTheme.ready : ColorTheme.warning
                )
            }

            Text("\(catalog.billingPreviewNotice) Launch pricing: \(catalog.launchPricingSummary).")
                .font(.footnote.weight(.medium))
                .foregroundStyle(ColorTheme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: 30,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: paywallAccent.opacity(0.14)
            ),
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: 30, edgeColor: paywallAccent.opacity(0.18), shadowColor: Color.black.opacity(0.26)))
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
        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accent.opacity(0.28), lineWidth: 1)
        )
    }

    private var paywallOutcomeColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    private var proOutcomes: [ProOutcome] {
        [
            ProOutcome(
                title: "Ask for offline answers",
                detail: "Get retrieval-first survival summaries when the internet is down.",
                systemImage: "sparkles",
                tint: ColorTheme.info
            ),
            ProOutcome(
                title: "Keep nearby comms alive",
                detail: "Hold local emergency signalling and structured reports closer at hand.",
                systemImage: "dot.radiowaves.left.and.right",
                tint: ColorTheme.ready
            ),
            ProOutcome(
                title: "Open tactical maps faster",
                detail: "Keep deeper basemaps and fallback navigation available when regular coverage fails.",
                systemImage: "map.fill",
                tint: ColorTheme.accent
            ),
            ProOutcome(
                title: "Plan readiness in more depth",
                detail: "Use richer evacuation, readiness, and vault workflows across the household.",
                systemImage: "checkmark.square.fill",
                tint: ColorTheme.warning
            )
        ]
    }

    private var paywallSpotlightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text("Recommended for year-round preparedness")
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)

                Spacer(minLength: 0)

                Text(catalog.recommendedOffer.shortPriceText + "/yr")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(paywallAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(paywallAccent.opacity(0.12), in: Capsule())
            }

            Text(catalog.recommendedOffer.detail)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(catalog.recommendedOffer.highlights, id: \.self) { highlight in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(paywallAccent)
                            .padding(.top, 2)

                        Text(highlight)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ColorTheme.text)
                    }
                }
            }
        }
        .padding(18)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: 24,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: paywallAccent.opacity(0.12)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: 24, edgeColor: paywallAccent.opacity(0.16), shadowColor: paywallAccent.opacity(0.05)))
    }

    private func paywallOutcomeCard(_ outcome: ProOutcome) -> some View {
        return VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(outcome.tint.opacity(0.14))
                    .frame(width: 40, height: 40)

                Image(systemName: outcome.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(outcome.tint)
            }

            Text(outcome.title)
                .font(.headline)
                .foregroundStyle(ColorTheme.text)

            Text(outcome.detail)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .leading)
        .padding(16)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: 22,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: outcome.tint.opacity(0.1)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: 22, edgeColor: outcome.tint.opacity(0.14), shadowColor: outcome.tint.opacity(0.05)))
    }

    private func paywallTrustRow(
        title: String,
        message: String,
        systemImage: String,
        tint: Color
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
        .background(
            PremiumSurfaceBackground(
                cornerRadius: 20,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: tint.opacity(0.08)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: 20, edgeColor: tint.opacity(0.12), shadowColor: tint.opacity(0.04)))
    }

    private func actionButton(
        title: String,
        subtitle: String,
        trailingText: String?,
        badge: String?,
        style: PaywallButtonStyleKind,
        action: @escaping () -> Void
    ) -> some View {
        return Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(style.titleColor)

                        if let badge {
                            Text(badge.uppercased())
                                .font(RediTypography.metadata)
                                .foregroundStyle(style.badgeTextColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(style.badgeBackground, in: Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(style.subtitleColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if let trailingText {
                    Text(trailingText)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(style.trailingColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(style.trailingBackground, in: Capsule())
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(style.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(style.borderColor, lineWidth: 1)
            )
            .shadow(color: style.shadowColor, radius: style.shadowRadius, y: style.shadowYOffset)
        }
        .buttonStyle(.plain)
    }
}

private enum PaywallButtonStyleKind {
    case primary
    case secondary
    case highlight

    var background: some ShapeStyle {
        switch self {
        case .primary:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [ColorTheme.accentSoft, ColorTheme.accent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .secondary:
            return AnyShapeStyle(Color.white.opacity(0.06))
        case .highlight:
            return AnyShapeStyle(ColorTheme.warning.opacity(0.16))
        }
    }

    var borderColor: Color {
        switch self {
        case .primary:
            return ColorTheme.accent.opacity(0.26)
        case .secondary:
            return Color.white.opacity(0.08)
        case .highlight:
            return ColorTheme.warning.opacity(0.28)
        }
    }

    var titleColor: Color {
        switch self {
        case .primary:
            return Color.black.opacity(0.88)
        case .secondary, .highlight:
            return ColorTheme.text
        }
    }

    var subtitleColor: Color {
        switch self {
        case .primary:
            return Color.black.opacity(0.62)
        case .secondary:
            return ColorTheme.textFaint
        case .highlight:
            return ColorTheme.warning.opacity(0.95)
        }
    }

    var trailingColor: Color {
        switch self {
        case .primary:
            return Color.black.opacity(0.82)
        case .secondary:
            return ColorTheme.text
        case .highlight:
            return ColorTheme.warning
        }
    }

    var trailingBackground: some ShapeStyle {
        switch self {
        case .primary:
            return AnyShapeStyle(Color.white.opacity(0.28))
        case .secondary:
            return AnyShapeStyle(Color.white.opacity(0.08))
        case .highlight:
            return AnyShapeStyle(ColorTheme.warning.opacity(0.14))
        }
    }

    var badgeBackground: some ShapeStyle {
        switch self {
        case .primary:
            return AnyShapeStyle(Color.black.opacity(0.12))
        case .secondary:
            return AnyShapeStyle(Color.white.opacity(0.08))
        case .highlight:
            return AnyShapeStyle(ColorTheme.warning.opacity(0.14))
        }
    }

    var badgeTextColor: Color {
        switch self {
        case .primary:
            return Color.black.opacity(0.78)
        case .secondary:
            return ColorTheme.textFaint
        case .highlight:
            return ColorTheme.warning
        }
    }

    var shadowColor: Color {
        switch self {
        case .primary:
            return ColorTheme.glowAmber.opacity(0.2)
        case .secondary:
            return Color.clear
        case .highlight:
            return ColorTheme.warning.opacity(0.1)
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .primary:
            18
        case .secondary:
            0
        case .highlight:
            14
        }
    }

    var shadowYOffset: CGFloat {
        switch self {
        case .primary:
            10
        case .secondary:
            0
        case .highlight:
            8
        }
    }
}

private struct ProOutcome: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
}

private enum PaywallScene: Int, CaseIterable, Identifiable {
    case blackout
    case storm
    case fire

    var id: Int { rawValue }

    var assetName: String {
        switch self {
        case .storm:
            "paywall_storm"
        case .fire:
            "paywall_fire"
        case .blackout:
            "paywall_blackout"
        }
    }

    var symbolName: String {
        switch self {
        case .storm:
            "cloud.bolt.rain.fill"
        case .fire:
            "flame.fill"
        case .blackout:
            "building.2.fill"
        }
    }

    var tint: Color {
        switch self {
        case .storm:
            ColorTheme.info
        case .fire:
            ColorTheme.warning
        case .blackout:
            Color(hex: "AAB1B8")
        }
    }

    var baseColors: [Color] {
        switch self {
        case .storm:
            [
                Color(hex: "17202A"),
                Color(hex: "0D131A"),
                ColorTheme.background
            ]
        case .fire:
            [
                Color(hex: "3A1607"),
                Color(hex: "120B08"),
                ColorTheme.background
            ]
        case .blackout:
            [
                Color(hex: "121A22"),
                Color(hex: "070B11"),
                ColorTheme.background
            ]
        }
    }

    var glowOffset: CGSize {
        switch self {
        case .storm:
            CGSize(width: -90, height: -20)
        case .fire:
            CGSize(width: 120, height: 40)
        case .blackout:
            CGSize(width: 80, height: -50)
        }
    }

    var highlightAngle: Angle {
        switch self {
        case .storm:
            .degrees(18)
        case .fire:
            .degrees(-4)
        case .blackout:
            .degrees(28)
        }
    }

    var highlightOffset: CGSize {
        switch self {
        case .storm:
            CGSize(width: -40, height: -80)
        case .fire:
            CGSize(width: 0, height: 80)
        case .blackout:
            CGSize(width: 80, height: -20)
        }
    }

    var symbolOffset: CGSize {
        switch self {
        case .storm:
            CGSize(width: 90, height: -20)
        case .fire:
            CGSize(width: -70, height: 80)
        case .blackout:
            CGSize(width: 60, height: 70)
        }
    }

    var idleScale: CGFloat { 1.03 }

    var activeScale: CGFloat {
        switch self {
        case .storm:
            1.1
        case .fire:
            1.08
        case .blackout:
            1.12
        }
    }

    var idleOffset: CGSize {
        switch self {
        case .storm:
            CGSize(width: -16, height: -6)
        case .fire:
            CGSize(width: 10, height: 10)
        case .blackout:
            CGSize(width: -8, height: 6)
        }
    }

    var activeOffset: CGSize {
        switch self {
        case .storm:
            CGSize(width: 18, height: 8)
        case .fire:
            CGSize(width: -18, height: -10)
        case .blackout:
            CGSize(width: 16, height: -12)
        }
    }
}
