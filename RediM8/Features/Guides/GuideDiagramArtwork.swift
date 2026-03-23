import SwiftUI

struct GuideDiagramPanel: View {
    let diagram: GuideDiagram
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GuideDiagramArtwork(diagram: diagram, accent: accent)
                .frame(width: 248, height: 160)
                .background(
                    LinearGradient(
                        colors: [ColorTheme.panelRaised, accent.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(accent.opacity(0.24), lineWidth: 1)
                )

            Text(diagram.title)
                .font(.headline)
                .foregroundStyle(ColorTheme.text)

            Text(diagram.caption)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.textSecondary)
        }
        .frame(width: 248, alignment: .leading)
    }
}

struct GuideDiagramArtwork: View {
    let diagram: GuideDiagram
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let assetName = diagram.assetName, diagram.kind == .imageAsset {
                    assetDiagramArt(assetName: assetName, in: proxy.size)
                } else {
                    switch diagram.kind {
                    case .imageAsset:
                        placeholderDiagramArt(kind: .pressureBandage, in: proxy.size)
                    case .pressureBandage:
                        pressureBandageArt(in: proxy.size)
                    case .recoveryPosition:
                        recoveryPositionArt(in: proxy.size)
                    case .bowline:
                        bowlineArt(in: proxy.size)
                    case .cloveHitch:
                        cloveHitchArt(in: proxy.size)
                    case .reefKnot:
                        reefKnotArt(in: proxy.size)
                    case .tarpRidgeline:
                        tarpRidgelineArt(in: proxy.size)
                    case .compassBearing:
                        compassBearingArt(in: proxy.size)
                    case .damperMethod:
                        damperMethodArt(in: proxy.size)
                    case .skilletBread:
                        skilletBreadArt(in: proxy.size)
                    case .sconeMethod:
                        sconeMethodArt(in: proxy.size)
                    case .raisedBedLayout:
                        raisedBedArt(in: proxy.size)
                    case .seedTray:
                        seedTrayArt(in: proxy.size)
                    case .potatoBag:
                        potatoBagArt(in: proxy.size)
                    case .waterFilter:
                        waterFilterArt(in: proxy.size)
                    case .bowDrill, .handDrill, .solarStill, .debrisHut, .leanTo,
                         .basicSnare, .fishTrap, .groundSignal, .signalFire,
                         .sunNavigation, .southernCross, .latrinePlacement,
                         .vehicleShelter, .condensationTrap:
                        placeholderDiagramArt(kind: diagram.kind, in: proxy.size)
                    }
                }
            }
            .padding(diagram.assetName == nil ? 18 : 8)
        }
    }

    // MARK: - Asset Diagram

    private func assetDiagramArt(assetName: String, in size: CGSize) -> some View {
        Image(assetName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Pressure Bandage

    private func pressureBandageArt(in size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .frame(width: size.width * 0.72, height: 52)

            Circle()
                .fill(ColorTheme.danger)
                .frame(width: 18, height: 18)
                .offset(x: -size.width * 0.10)

            ForEach(0..<6, id: \.self) { index in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(accent.opacity(0.86))
                    .frame(width: size.width * 0.12, height: 56)
                    .rotationEffect(.degrees(26))
                    .offset(x: CGFloat(index - 2) * 26)
            }

            Text("Firm bandage")
                .font(.caption.weight(.bold))
                .foregroundStyle(ColorTheme.text)
                .offset(y: 44)
        }
    }

    // MARK: - Recovery Position

    private func recoveryPositionArt(in size: CGSize) -> some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.06))
                .frame(width: size.width * 0.50, height: 32)
                .rotationEffect(.degrees(18))
                .offset(x: -12, y: -8)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 30, height: 30)
                .offset(x: size.width * 0.18, y: -30)

            Path { path in
                path.move(to: CGPoint(x: size.width * 0.38, y: size.height * 0.58))
                path.addLine(to: CGPoint(x: size.width * 0.54, y: size.height * 0.46))
                path.addLine(to: CGPoint(x: size.width * 0.65, y: size.height * 0.62))
            }
            .stroke(accent, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))

            Text("Side position")
                .font(.caption.weight(.bold))
                .foregroundStyle(ColorTheme.text)
                .offset(y: 44)
        }
    }

    // MARK: - Bowline

    private func bowlineArt(in size: CGSize) -> some View {
        ZStack {
            Circle()
                .stroke(ColorTheme.accent, lineWidth: 10)
                .frame(width: size.width * 0.34, height: size.width * 0.34)
                .offset(x: -34, y: -4)

            Path { path in
                path.move(to: CGPoint(x: size.width * 0.56, y: size.height * 0.26))
                path.addCurve(
                    to: CGPoint(x: size.width * 0.52, y: size.height * 0.74),
                    control1: CGPoint(x: size.width * 0.62, y: size.height * 0.40),
                    control2: CGPoint(x: size.width * 0.60, y: size.height * 0.62)
                )
                path.addCurve(
                    to: CGPoint(x: size.width * 0.34, y: size.height * 0.54),
                    control1: CGPoint(x: size.width * 0.46, y: size.height * 0.70),
                    control2: CGPoint(x: size.width * 0.38, y: size.height * 0.64)
                )
            }
            .stroke(accent, style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))

            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.title2)
                .foregroundStyle(ColorTheme.warning)
                .offset(x: 52, y: -34)
        }
    }

    // MARK: - Clove Hitch

    private func cloveHitchArt(in size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(width: 28, height: size.height * 0.68)

            ForEach([-18.0, 18.0], id: \.self) { offset in
                Circle()
                    .stroke(accent, lineWidth: 10)
                    .frame(width: 68, height: 68)
                    .offset(x: offset)
            }

            Image(systemName: "arrow.left.and.right.circle.fill")
                .font(.title2)
                .foregroundStyle(ColorTheme.warning)
                .offset(y: 44)
        }
    }

    // MARK: - Reef Knot

    private func reefKnotArt(in size: CGSize) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.18, y: size.height * 0.38))
                path.addCurve(
                    to: CGPoint(x: size.width * 0.50, y: size.height * 0.52),
                    control1: CGPoint(x: size.width * 0.32, y: size.height * 0.34),
                    control2: CGPoint(x: size.width * 0.38, y: size.height * 0.60)
                )
                path.addCurve(
                    to: CGPoint(x: size.width * 0.82, y: size.height * 0.36),
                    control1: CGPoint(x: size.width * 0.62, y: size.height * 0.44),
                    control2: CGPoint(x: size.width * 0.68, y: size.height * 0.30)
                )
            }
            .stroke(accent, style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))

            Path { path in
                path.move(to: CGPoint(x: size.width * 0.18, y: size.height * 0.62))
                path.addCurve(
                    to: CGPoint(x: size.width * 0.50, y: size.height * 0.46),
                    control1: CGPoint(x: size.width * 0.30, y: size.height * 0.70),
                    control2: CGPoint(x: size.width * 0.40, y: size.height * 0.36)
                )
                path.addCurve(
                    to: CGPoint(x: size.width * 0.82, y: size.height * 0.64),
                    control1: CGPoint(x: size.width * 0.60, y: size.height * 0.58),
                    control2: CGPoint(x: size.width * 0.72, y: size.height * 0.72)
                )
            }
            .stroke(ColorTheme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: - Tarp Ridgeline

    private func tarpRidgelineArt(in size: CGSize) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: size.width * 0.68, height: 4)
                .offset(y: -24)

            Triangle()
                .fill(accent.opacity(0.84))
                .frame(width: size.width * 0.66, height: size.height * 0.38)
                .offset(y: -2)

            ForEach([-68.0, 68.0], id: \.self) { offset in
                Path { path in
                    path.move(to: CGPoint(x: size.width * 0.50 + offset, y: size.height * 0.46))
                    path.addLine(to: CGPoint(x: size.width * 0.50 + offset, y: size.height * 0.76))
                }
                .stroke(ColorTheme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
        }
    }

    // MARK: - Compass Bearing

    private func compassBearingArt(in size: CGSize) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: 5)
                .frame(width: size.height * 0.64, height: size.height * 0.64)

            Image(systemName: "location.north.line.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(accent)
                .rotationEffect(.degrees(-32))

            Text("Bearing")
                .font(.caption.weight(.bold))
                .foregroundStyle(ColorTheme.text)
                .offset(y: 48)
        }
    }

    // MARK: - Food Diagrams

    private func damperMethodArt(in size: CGSize) -> some View {
        ingredientRatioArt(
            title: "Flour",
            middle: "Water",
            end: "Pinch salt",
            leftColor: accent,
            middleColor: ColorTheme.accent,
            endColor: ColorTheme.warning
        )
    }

    private func skilletBreadArt(in size: CGSize) -> some View {
        ZStack {
            ingredientRatioArt(
                title: "Flour",
                middle: "Yeast",
                end: "Water",
                leftColor: accent,
                middleColor: ColorTheme.warning,
                endColor: ColorTheme.accent
            )

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ColorTheme.textTertiary, lineWidth: 4)
                .frame(width: size.width * 0.28, height: size.height * 0.16)
                .offset(y: 42)
        }
    }

    private func sconeMethodArt(in size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(accent.opacity(0.22))
                .frame(width: size.width * 0.62, height: size.height * 0.32)

            ForEach([-40.0, 0.0, 40.0], id: \.self) { offset in
                Circle()
                    .fill(ColorTheme.warning.opacity(0.88))
                    .frame(width: 30, height: 30)
                    .offset(x: offset, y: 4)
            }

            Text("Cut \u{2022} Bake")
                .font(.caption.weight(.bold))
                .foregroundStyle(ColorTheme.text)
                .offset(y: 46)
        }
    }

    // MARK: - Garden Diagrams

    private func raisedBedArt(in size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accent, lineWidth: 4)
                .frame(width: size.width * 0.70, height: size.height * 0.48)

            ForEach(0..<3, id: \.self) { row in
                ForEach(0..<4, id: \.self) { column in
                    Circle()
                        .fill(ColorTheme.ready)
                        .frame(width: 12, height: 12)
                        .offset(
                            x: CGFloat(column - 1) * 34 - 16,
                            y: CGFloat(row - 1) * 26
                        )
                }
            }
        }
    }

    private func seedTrayArt(in size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ColorTheme.accent, lineWidth: 4)
                .frame(width: size.width * 0.66, height: size.height * 0.42)

            ForEach(0..<3, id: \.self) { row in
                ForEach(0..<4, id: \.self) { column in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(accent.opacity(0.22))
                        .frame(width: 30, height: 24)
                        .offset(x: CGFloat(column - 1) * 34 - 16, y: CGFloat(row - 1) * 22)
                }
            }

            Image(systemName: "leaf.fill")
                .font(.title2)
                .foregroundStyle(ColorTheme.ready)
                .offset(y: -42)
        }
    }

    private func potatoBagArt(in size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(width: size.width * 0.34, height: size.height * 0.56)

            ForEach([-12.0, 12.0], id: \.self) { offset in
                Circle()
                    .fill(ColorTheme.warning)
                    .frame(width: 24, height: 24)
                    .offset(x: offset, y: 18)
            }

            Image(systemName: "leaf.fill")
                .font(.title)
                .foregroundStyle(accent)
                .offset(y: -34)
        }
    }

    // MARK: - Water Filter

    private func waterFilterArt(in size: CGSize) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.36, y: size.height * 0.20))
                path.addLine(to: CGPoint(x: size.width * 0.64, y: size.height * 0.20))
                path.addLine(to: CGPoint(x: size.width * 0.54, y: size.height * 0.72))
                path.addLine(to: CGPoint(x: size.width * 0.46, y: size.height * 0.72))
                path.closeSubpath()
            }
            .fill(accent.opacity(0.18))
            .overlay {
                Path { path in
                    path.move(to: CGPoint(x: size.width * 0.36, y: size.height * 0.20))
                    path.addLine(to: CGPoint(x: size.width * 0.64, y: size.height * 0.20))
                    path.addLine(to: CGPoint(x: size.width * 0.54, y: size.height * 0.72))
                    path.addLine(to: CGPoint(x: size.width * 0.46, y: size.height * 0.72))
                    path.closeSubpath()
                }
                .stroke(accent, lineWidth: 4)
            }

            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ColorTheme.warning)
                    .frame(width: 52, height: 10)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ColorTheme.textTertiary)
                    .frame(width: 52, height: 10)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ColorTheme.accent)
                    .frame(width: 52, height: 10)
            }
        }
    }

    // MARK: - Placeholder

    private func placeholderDiagramArt(kind: GuideDiagramKind, in size: CGSize) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "square.dashed")
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(accent.opacity(0.4))
            Text(kind.rawValue.replacingOccurrences(of: "_", with: " ").uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(ColorTheme.textTertiary)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Helpers

    private func ingredientRatioArt(
        title: String,
        middle: String,
        end: String,
        leftColor: Color,
        middleColor: Color,
        endColor: Color
    ) -> some View {
        HStack(spacing: 12) {
            ratioBubble(title: title, color: leftColor)
            ratioBubble(title: middle, color: middleColor)
            ratioBubble(title: end, color: endColor)
        }
    }

    private func ratioBubble(title: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(color.opacity(0.22))
                .frame(width: 42, height: 42)
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.34), lineWidth: 1)
                )
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(ColorTheme.text)
                .multilineTextAlignment(.center)
                .frame(width: 58)
        }
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
