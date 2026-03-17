import SwiftUI

// MARK: - Solar Still Construction — 5 Procedural Steps

struct SolarStillDiagrams {

    @ViewBuilder
    static func view(for step: ProceduralDiagramStep, accent: Color) -> some View {
        switch step.id {
        case "solar_still_1": digPitView(accent: accent)
        case "solar_still_2": placeContainerView(accent: accent)
        case "solar_still_3": addVegetationView(accent: accent)
        case "solar_still_4": sealPlasticView(accent: accent)
        case "solar_still_5": condensationView(accent: accent)
        default: EmptyView()
        }
    }

    // MARK: Step 1 — Dig the Pit

    private static func digPitView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Surface ground
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.35))
                    p.addLine(to: CGPoint(x: w * 0.20, y: h * 0.35))
                    p.addLine(to: CGPoint(x: w * 0.22, y: h * 0.38))
                    p.addLine(to: CGPoint(x: w * 0.22, y: h * 0.80))
                    p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.80))
                    p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.38))
                    p.addLine(to: CGPoint(x: w * 0.80, y: h * 0.35))
                    p.addLine(to: CGPoint(x: w, y: h * 0.35))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)

                // Earth fill (cross-section hatching)
                Path { p in
                    p.addRect(CGRect(x: 0, y: h * 0.36, width: w * 0.20, height: h * 0.50))
                    p.addRect(CGRect(x: w * 0.80, y: h * 0.36, width: w * 0.20, height: h * 0.50))
                }
                .fill(Color.white.opacity(0.03))

                // Depth dimension
                DiagramDimensionLine(
                    from: CGPoint(x: 0.85, y: 0.35),
                    to: CGPoint(x: 0.85, y: 0.80),
                    label: "60CM",
                    color: accent
                )

                // Width dimension
                DiagramDimensionLine(
                    from: CGPoint(x: 0.22, y: 0.88),
                    to: CGPoint(x: 0.78, y: 0.88),
                    label: "90CM",
                    color: accent
                )

                // Sun indicator
                Path { p in
                    let cx = w * 0.50
                    let cy = h * 0.10
                    p.addEllipse(in: CGRect(x: cx - 8, y: cy - 8, width: 16, height: 16))
                }
                .stroke(ColorTheme.warning.opacity(0.5), lineWidth: 1.5)

                // Sun rays
                ForEach(0..<8, id: \.self) { i in
                    let angle = CGFloat(i) * .pi / 4
                    let cx = w * 0.50
                    let cy = h * 0.10
                    Path { p in
                        p.move(to: CGPoint(x: cx + cos(angle) * 12, y: cy + sin(angle) * 12))
                        p.addLine(to: CGPoint(x: cx + cos(angle) * 18, y: cy + sin(angle) * 18))
                    }
                    .stroke(ColorTheme.warning.opacity(0.3), lineWidth: 1)
                }

                DiagramLabel("FULL SUN", at: CGPoint(x: 0.50, y: 0.22), color: ColorTheme.warning.opacity(0.6), size: 9)
                DiagramLabel("MOIST GROUND OR DRY CREEK BED", at: CGPoint(x: 0.50, y: 0.95), color: Color.white.opacity(0.4), size: 8)
            }
        }
    }

    // MARK: Step 2 — Place Container

    private static func placeContainerView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Pit cross-section
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.35))
                    p.addLine(to: CGPoint(x: w * 0.22, y: h * 0.35))
                    p.addLine(to: CGPoint(x: w * 0.22, y: h * 0.80))
                    p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.80))
                    p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.35))
                    p.addLine(to: CGPoint(x: w, y: h * 0.35))
                }
                .stroke(Color.white.opacity(0.4), lineWidth: 1.5)

                // Container (cup shape)
                Path { p in
                    let cx = w * 0.50
                    let top = h * 0.62
                    let bottom = h * 0.79
                    let halfW: CGFloat = 12
                    p.move(to: CGPoint(x: cx - halfW, y: top))
                    p.addLine(to: CGPoint(x: cx - halfW + 3, y: bottom))
                    p.addLine(to: CGPoint(x: cx + halfW - 3, y: bottom))
                    p.addLine(to: CGPoint(x: cx + halfW, y: top))
                }
                .stroke(accent, lineWidth: 2)

                DiagramCallout(text: "CONTAINER", pointTo: CGPoint(x: 0.50, y: 0.70), labelAt: CGPoint(x: 0.75, y: 0.58), color: accent)
                DiagramLabel("CENTRE OF HOLE", at: CGPoint(x: 0.50, y: 0.90), color: accent.opacity(0.6), size: 9)

                // Centre line (dashed)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.50, y: h * 0.30))
                    p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.60))
                }
                .stroke(accent.opacity(0.2), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            }
        }
    }

    // MARK: Step 3 — Add Vegetation

    private static func addVegetationView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Pit
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.35))
                    p.addLine(to: CGPoint(x: w * 0.22, y: h * 0.35))
                    p.addLine(to: CGPoint(x: w * 0.22, y: h * 0.80))
                    p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.80))
                    p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.35))
                    p.addLine(to: CGPoint(x: w, y: h * 0.35))
                }
                .stroke(Color.white.opacity(0.4), lineWidth: 1.5)

                // Container
                Path { p in
                    let cx = w * 0.50
                    p.move(to: CGPoint(x: cx - 12, y: h * 0.62))
                    p.addLine(to: CGPoint(x: cx - 9, y: h * 0.79))
                    p.addLine(to: CGPoint(x: cx + 9, y: h * 0.79))
                    p.addLine(to: CGPoint(x: cx + 12, y: h * 0.62))
                }
                .stroke(accent.opacity(0.5), lineWidth: 1.5)

                // Vegetation patches (left of container)
                ForEach(0..<3, id: \.self) { i in
                    let x = w * (0.27 + CGFloat(i) * 0.04)
                    let y = h * 0.68
                    Path { p in
                        p.move(to: CGPoint(x: x, y: y + 8))
                        p.addQuadCurve(to: CGPoint(x: x + 3, y: y - 5), control: CGPoint(x: x - 4, y: y))
                        p.move(to: CGPoint(x: x, y: y + 8))
                        p.addQuadCurve(to: CGPoint(x: x - 2, y: y - 3), control: CGPoint(x: x + 3, y: y))
                    }
                    .stroke(ColorTheme.ready.opacity(0.5), lineWidth: 1)
                }

                // Vegetation patches (right of container)
                ForEach(0..<3, id: \.self) { i in
                    let x = w * (0.62 + CGFloat(i) * 0.04)
                    let y = h * 0.68
                    Path { p in
                        p.move(to: CGPoint(x: x, y: y + 8))
                        p.addQuadCurve(to: CGPoint(x: x + 3, y: y - 5), control: CGPoint(x: x - 4, y: y))
                        p.move(to: CGPoint(x: x, y: y + 8))
                        p.addQuadCurve(to: CGPoint(x: x - 2, y: y - 3), control: CGPoint(x: x + 3, y: y))
                    }
                    .stroke(ColorTheme.ready.opacity(0.5), lineWidth: 1)
                }

                DiagramCallout(text: "VEGETATION", pointTo: CGPoint(x: 0.32, y: 0.68), labelAt: CGPoint(x: 0.20, y: 0.50), color: ColorTheme.ready)
                DiagramCallout(text: "KEEP CLEAR", pointTo: CGPoint(x: 0.50, y: 0.65), labelAt: CGPoint(x: 0.50, y: 0.20), color: accent)

                DiagramLabel("AROUND · NOT IN CONTAINER", at: CGPoint(x: 0.50, y: 0.92), color: accent, size: 9)
            }
        }
    }

    // MARK: Step 4 — Seal with Plastic

    private static func sealPlasticView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Pit
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.35))
                    p.addLine(to: CGPoint(x: w * 0.22, y: h * 0.35))
                    p.addLine(to: CGPoint(x: w * 0.22, y: h * 0.80))
                    p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.80))
                    p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.35))
                    p.addLine(to: CGPoint(x: w, y: h * 0.35))
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)

                // Container
                Path { p in
                    let cx = w * 0.50
                    p.move(to: CGPoint(x: cx - 12, y: h * 0.62))
                    p.addLine(to: CGPoint(x: cx - 9, y: h * 0.79))
                    p.addLine(to: CGPoint(x: cx + 9, y: h * 0.79))
                    p.addLine(to: CGPoint(x: cx + 12, y: h * 0.62))
                }
                .stroke(accent.opacity(0.4), lineWidth: 1.5)

                // Plastic sheet — V-shape draped over pit
                Path { p in
                    p.move(to: CGPoint(x: w * 0.12, y: h * 0.32))
                    p.addQuadCurve(
                        to: CGPoint(x: w * 0.50, y: h * 0.50),
                        control: CGPoint(x: w * 0.35, y: h * 0.34)
                    )
                    p.addQuadCurve(
                        to: CGPoint(x: w * 0.88, y: h * 0.32),
                        control: CGPoint(x: w * 0.65, y: h * 0.34)
                    )
                }
                .stroke(Color.white.opacity(0.6), lineWidth: 2)

                // Stone weight at centre
                Path { p in
                    p.addEllipse(in: CGRect(x: w * 0.47, y: h * 0.46, width: 12, height: 8))
                }
                .fill(Color.white.opacity(0.3))
                .overlay(
                    Path { p in
                        p.addEllipse(in: CGRect(x: w * 0.47, y: h * 0.46, width: 12, height: 8))
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )

                DiagramCallout(text: "STONE", pointTo: CGPoint(x: 0.50, y: 0.49), labelAt: CGPoint(x: 0.72, y: 0.42), color: Color.white.opacity(0.7))

                // Edge seals (dirt/rocks)
                ForEach([0.14, 0.86], id: \.self) { xFrac in
                    Path { p in
                        let x = w * CGFloat(xFrac)
                        p.addEllipse(in: CGRect(x: x - 6, y: h * 0.30, width: 12, height: 8))
                    }
                    .fill(Color.white.opacity(0.15))
                    .overlay(
                        Path { p in
                            let x = w * CGFloat(xFrac)
                            p.addEllipse(in: CGRect(x: x - 6, y: h * 0.30, width: 12, height: 8))
                        }
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                }

                DiagramCallout(text: "SEAL\nEDGES", pointTo: CGPoint(x: 0.14, y: 0.33), labelAt: CGPoint(x: 0.14, y: 0.18), color: accent)

                DiagramLabel("AIRTIGHT · NO GAPS", at: CGPoint(x: 0.50, y: 0.92), color: accent, size: 9)
            }
        }
    }

    // MARK: Step 5 — Condensation Cycle

    private static func condensationView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Pit (faint)
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.35))
                    p.addLine(to: CGPoint(x: w * 0.22, y: h * 0.35))
                    p.addLine(to: CGPoint(x: w * 0.22, y: h * 0.80))
                    p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.80))
                    p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.35))
                    p.addLine(to: CGPoint(x: w, y: h * 0.35))
                }
                .stroke(Color.white.opacity(0.2), lineWidth: 1)

                // Plastic sheet
                Path { p in
                    p.move(to: CGPoint(x: w * 0.12, y: h * 0.32))
                    p.addQuadCurve(to: CGPoint(x: w * 0.50, y: h * 0.50), control: CGPoint(x: w * 0.35, y: h * 0.34))
                    p.addQuadCurve(to: CGPoint(x: w * 0.88, y: h * 0.32), control: CGPoint(x: w * 0.65, y: h * 0.34))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)

                // Container
                Path { p in
                    let cx = w * 0.50
                    p.move(to: CGPoint(x: cx - 12, y: h * 0.62))
                    p.addLine(to: CGPoint(x: cx - 9, y: h * 0.79))
                    p.addLine(to: CGPoint(x: cx + 9, y: h * 0.79))
                    p.addLine(to: CGPoint(x: cx + 12, y: h * 0.62))
                }
                .stroke(accent, lineWidth: 2)

                // Water in container
                Path { p in
                    p.addRect(CGRect(x: w * 0.50 - 8, y: h * 0.72, width: 16, height: h * 0.06))
                }
                .fill(accent.opacity(0.3))

                // Sun → Heat arrows (down from sun)
                DiagramArrow(from: CGPoint(x: 0.40, y: 0.08), to: CGPoint(x: 0.35, y: 0.30))
                    .stroke(ColorTheme.warning.opacity(0.4), lineWidth: 1)
                DiagramArrow(from: CGPoint(x: 0.60, y: 0.08), to: CGPoint(x: 0.65, y: 0.30))
                    .stroke(ColorTheme.warning.opacity(0.4), lineWidth: 1)

                // Evaporation arrows (up from ground)
                DiagramArrow(from: CGPoint(x: 0.35, y: 0.75), to: CGPoint(x: 0.35, y: 0.55))
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                DiagramArrow(from: CGPoint(x: 0.65, y: 0.75), to: CGPoint(x: 0.65, y: 0.55))
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)

                DiagramLabel("EVAP", at: CGPoint(x: 0.28, y: 0.64), color: Color.white.opacity(0.4), size: 8)

                // Condensation dots on underside of plastic
                ForEach(0..<5, id: \.self) { i in
                    let t = CGFloat(i) / 4.0
                    let x = w * (0.30 + t * 0.40)
                    let y = h * (0.36 + abs(t - 0.5) * -0.16 + 0.08)
                    Circle()
                        .fill(accent.opacity(0.4))
                        .frame(width: 3, height: 3)
                        .position(x: x, y: y)
                }

                // Drip path to container
                Path { p in
                    p.move(to: CGPoint(x: w * 0.50, y: h * 0.50))
                    p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.62))
                }
                .stroke(accent, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))

                // Drip drops
                Circle()
                    .fill(accent)
                    .frame(width: 4, height: 4)
                    .position(x: w * 0.50, y: h * 0.56)

                DiagramLabel("DRIP", at: CGPoint(x: 0.55, y: 0.56), color: accent, size: 8)
                DiagramLabel("CONDENSE", at: CGPoint(x: 0.75, y: 0.40), color: accent.opacity(0.6), size: 8)
                DiagramLabel("200–500ML/DAY", at: CGPoint(x: 0.50, y: 0.92), color: accent, size: 9)

                // Sun
                Path { p in
                    p.addEllipse(in: CGRect(x: w * 0.46, y: h * 0.02, width: 12, height: 12))
                }
                .stroke(ColorTheme.warning.opacity(0.5), lineWidth: 1.5)
            }
        }
    }
}
