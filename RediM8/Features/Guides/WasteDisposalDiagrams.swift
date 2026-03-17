import SwiftUI

// MARK: - Waste Disposal Setup — 4 Procedural Steps

struct WasteDisposalDiagrams {

    @ViewBuilder
    static func view(for step: ProceduralDiagramStep, accent: Color) -> some View {
        switch step.id {
        case "waste_1": distanceLayoutView(accent: accent)
        case "waste_2": catHoleView(accent: accent)
        case "waste_3": slitTrenchView(accent: accent)
        case "waste_4": handHygieneView(accent: accent)
        default: EmptyView()
        }
    }

    // MARK: Step 1 — Distance Layout (top-down camp plan)

    private static func distanceLayoutView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Camp (centre)
                Path { p in
                    let cx = w * 0.50
                    let cy = h * 0.45
                    p.addRoundedRect(in: CGRect(x: cx - 16, y: cy - 12, width: 32, height: 24), cornerSize: CGSize(width: 3, height: 3))
                }
                .fill(Color.white.opacity(0.1))
                .overlay(
                    Path { p in
                        let cx = w * 0.50
                        let cy = h * 0.45
                        p.addRoundedRect(in: CGRect(x: cx - 16, y: cy - 12, width: 32, height: 24), cornerSize: CGSize(width: 3, height: 3))
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                )

                DiagramLabel("CAMP", at: CGPoint(x: 0.50, y: 0.45), color: Color.white.opacity(0.7), size: 9)

                // Water source (top-right)
                Path { p in
                    p.addEllipse(in: CGRect(x: w * 0.78, y: h * 0.12, width: 18, height: 12))
                }
                .fill(accent.opacity(0.15))
                .overlay(
                    Path { p in
                        p.addEllipse(in: CGRect(x: w * 0.78, y: h * 0.12, width: 18, height: 12))
                    }
                    .stroke(accent.opacity(0.5), lineWidth: 1)
                )

                DiagramLabel("WATER", at: CGPoint(x: 0.85, y: 0.10), color: accent, size: 8)

                // Food prep area (top-left)
                Path { p in
                    p.addRoundedRect(in: CGRect(x: w * 0.12, y: h * 0.15, width: 20, height: 14), cornerSize: CGSize(width: 2, height: 2))
                }
                .stroke(ColorTheme.warning.opacity(0.5), lineWidth: 1)

                DiagramLabel("FOOD", at: CGPoint(x: 0.15, y: 0.12), color: ColorTheme.warning.opacity(0.7), size: 8)

                // Latrine zone (bottom-left, downhill)
                Path { p in
                    p.addRoundedRect(in: CGRect(x: w * 0.08, y: h * 0.72, width: 24, height: 16), cornerSize: CGSize(width: 3, height: 3))
                }
                .fill(ColorTheme.danger.opacity(0.08))
                .overlay(
                    Path { p in
                        p.addRoundedRect(in: CGRect(x: w * 0.08, y: h * 0.72, width: 24, height: 16), cornerSize: CGSize(width: 3, height: 3))
                    }
                    .stroke(ColorTheme.danger.opacity(0.4), lineWidth: 1)
                )

                DiagramLabel("LATRINE", at: CGPoint(x: 0.12, y: 0.80), color: ColorTheme.danger.opacity(0.7), size: 8)

                // Distance lines — camp to latrine
                DiagramDimensionLine(
                    from: CGPoint(x: 0.42, y: 0.52),
                    to: CGPoint(x: 0.18, y: 0.72),
                    label: "60M+",
                    color: accent
                )

                // Distance — latrine to water
                DiagramDimensionLine(
                    from: CGPoint(x: 0.20, y: 0.72),
                    to: CGPoint(x: 0.78, y: 0.18),
                    label: "60M+",
                    color: accent
                )

                // Downhill arrow
                DiagramArrow(from: CGPoint(x: 0.50, y: 0.60), to: CGPoint(x: 0.30, y: 0.72))
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)

                DiagramLabel("DOWNHILL", at: CGPoint(x: 0.42, y: 0.68), color: Color.white.opacity(0.4), size: 8)

                // Wind arrow
                DiagramArrow(from: CGPoint(x: 0.50, y: 0.30), to: CGPoint(x: 0.25, y: 0.65))
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)

                DiagramLabel("WIND", at: CGPoint(x: 0.42, y: 0.32), color: Color.white.opacity(0.3), size: 8)

                DiagramLabel("TOP VIEW", at: CGPoint(x: 0.88, y: 0.92), color: Color.white.opacity(0.3), size: 8)
            }
        }
    }

    // MARK: Step 2 — Cat Hole

    private static func catHoleView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Surface
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.40))
                    p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.40))
                    p.addLine(to: CGPoint(x: w * 0.32, y: h * 0.42))
                    p.addLine(to: CGPoint(x: w * 0.32, y: h * 0.68))
                    p.addLine(to: CGPoint(x: w * 0.58, y: h * 0.68))
                    p.addLine(to: CGPoint(x: w * 0.58, y: h * 0.42))
                    p.addLine(to: CGPoint(x: w * 0.60, y: h * 0.40))
                    p.addLine(to: CGPoint(x: w, y: h * 0.40))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)

                // Earth hatching
                Path { p in
                    p.addRect(CGRect(x: 0, y: h * 0.41, width: w * 0.30, height: h * 0.40))
                    p.addRect(CGRect(x: w * 0.60, y: h * 0.41, width: w * 0.40, height: h * 0.40))
                }
                .fill(Color.white.opacity(0.03))

                // Depth dimension
                DiagramDimensionLine(
                    from: CGPoint(x: 0.65, y: 0.40),
                    to: CGPoint(x: 0.65, y: 0.68),
                    label: "15-20CM",
                    color: accent
                )

                // Cover soil arrow
                DiagramArrow(from: CGPoint(x: 0.80, y: 0.30), to: CGPoint(x: 0.55, y: 0.42))
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)

                // Soil pile
                Path { p in
                    p.move(to: CGPoint(x: w * 0.72, y: h * 0.38))
                    p.addQuadCurve(
                        to: CGPoint(x: w * 0.88, y: h * 0.38),
                        control: CGPoint(x: w * 0.80, y: h * 0.25))
                }
                .fill(Color.white.opacity(0.06))
                .overlay(
                    Path { p in
                        p.move(to: CGPoint(x: w * 0.72, y: h * 0.38))
                        p.addQuadCurve(
                            to: CGPoint(x: w * 0.88, y: h * 0.38),
                            control: CGPoint(x: w * 0.80, y: h * 0.25))
                    }
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )

                DiagramLabel("COVER\nAFTER", at: CGPoint(x: 0.80, y: 0.20), color: accent.opacity(0.7), size: 9)

                // Mark indicator
                Path { p in
                    let cx = w * 0.45
                    let y = h * 0.32
                    p.move(to: CGPoint(x: cx - 6, y: y - 6))
                    p.addLine(to: CGPoint(x: cx + 6, y: y + 6))
                    p.move(to: CGPoint(x: cx + 6, y: y - 6))
                    p.addLine(to: CGPoint(x: cx - 6, y: y + 6))
                }
                .stroke(ColorTheme.warning, lineWidth: 1.5)

                DiagramLabel("MARK SITE", at: CGPoint(x: 0.45, y: 0.22), color: ColorTheme.warning.opacity(0.7), size: 8)

                DiagramLabel("CROSS SECTION", at: CGPoint(x: 0.50, y: 0.92), color: Color.white.opacity(0.3), size: 8)
            }
        }
    }

    // MARK: Step 3 — Slit Trench

    private static func slitTrenchView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Surface
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.30))
                    p.addLine(to: CGPoint(x: w * 0.28, y: h * 0.30))
                    p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.33))
                    p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.72))
                    p.addLine(to: CGPoint(x: w * 0.52, y: h * 0.72))
                    p.addLine(to: CGPoint(x: w * 0.52, y: h * 0.33))
                    p.addLine(to: CGPoint(x: w * 0.54, y: h * 0.30))
                    p.addLine(to: CGPoint(x: w, y: h * 0.30))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)

                // Fill level indicator
                Path { p in
                    p.move(to: CGPoint(x: w * 0.30, y: h * 0.62))
                    p.addLine(to: CGPoint(x: w * 0.52, y: h * 0.62))
                }
                .stroke(accent, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))

                // Partial fill
                Path { p in
                    p.addRect(CGRect(x: w * 0.30, y: h * 0.62, width: w * 0.22, height: h * 0.10))
                }
                .fill(Color.white.opacity(0.04))

                // Depth
                DiagramDimensionLine(
                    from: CGPoint(x: 0.58, y: 0.30),
                    to: CGPoint(x: 0.58, y: 0.72),
                    label: "60CM",
                    color: accent
                )

                // Width
                DiagramDimensionLine(
                    from: CGPoint(x: 0.30, y: 0.80),
                    to: CGPoint(x: 0.52, y: 0.80),
                    label: "30CM",
                    color: accent
                )

                // Length indicator (perspective)
                DiagramArrow(from: CGPoint(x: 0.41, y: 0.50), to: CGPoint(x: 0.80, y: 0.20))
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)

                DiagramLabel("1M+ LONG", at: CGPoint(x: 0.72, y: 0.16), color: accent.opacity(0.6), size: 9)

                // Fill level label
                DiagramCallout(text: "FILL TO\nHERE", pointTo: CGPoint(x: 0.41, y: 0.62), labelAt: CGPoint(x: 0.18, y: 0.55), color: accent)

                // Cover soil per use
                DiagramArrow(from: CGPoint(x: 0.20, y: 0.38), to: CGPoint(x: 0.35, y: 0.45))
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)

                DiagramLabel("THIN SOIL\nEACH USE", at: CGPoint(x: 0.15, y: 0.32), color: Color.white.opacity(0.5), size: 8)

                DiagramLabel("CROSS SECTION", at: CGPoint(x: 0.50, y: 0.92), color: Color.white.opacity(0.3), size: 8)
            }
        }
    }

    // MARK: Step 4 — Hand Hygiene

    private static func handHygieneView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Three method panels side by side

                // Panel 1: Ash + Water
                let p1x = w * 0.17
                Path { p in
                    p.addRoundedRect(in: CGRect(x: p1x - w * 0.13, y: h * 0.15, width: w * 0.26, height: h * 0.60), cornerSize: CGSize(width: 4, height: 4))
                }
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)

                // Ash pile
                Path { p in
                    p.move(to: CGPoint(x: p1x - 10, y: h * 0.52))
                    p.addQuadCurve(to: CGPoint(x: p1x + 10, y: h * 0.52), control: CGPoint(x: p1x, y: h * 0.38))
                }
                .fill(Color.white.opacity(0.1))
                .overlay(
                    Path { p in
                        p.move(to: CGPoint(x: p1x - 10, y: h * 0.52))
                        p.addQuadCurve(to: CGPoint(x: p1x + 10, y: h * 0.52), control: CGPoint(x: p1x, y: h * 0.38))
                    }
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )

                // Water drops
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(accent.opacity(0.3))
                        .frame(width: 4, height: 4)
                        .position(x: p1x + CGFloat(i - 1) * 6, y: h * 0.58)
                }

                DiagramLabel("ASH\n+ WATER", at: CGPoint(x: 0.17, y: 0.28), color: accent, size: 9)
                DiagramLabel("ANTISEPTIC", at: CGPoint(x: 0.17, y: 0.68), color: Color.white.opacity(0.4), size: 7)

                // Panel 2: Sand Scrub
                let p2x = w * 0.50
                Path { p in
                    p.addRoundedRect(in: CGRect(x: p2x - w * 0.13, y: h * 0.15, width: w * 0.26, height: h * 0.60), cornerSize: CGSize(width: 4, height: 4))
                }
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)

                // Sand texture (dots)
                ForEach(0..<8, id: \.self) { i in
                    let ox = CGFloat.random(in: -8...8)
                    let oy = CGFloat.random(in: -5...5)
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 2, height: 2)
                        .position(x: p2x + ox, y: h * 0.48 + oy)
                }

                // Scrubbing motion
                DiagramDoubleArrow(y: 0.55, xStart: 0.42, xEnd: 0.58)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)

                DiagramLabel("SAND\nSCRUB", at: CGPoint(x: 0.50, y: 0.28), color: accent, size: 9)
                DiagramLabel("ABRASIVE", at: CGPoint(x: 0.50, y: 0.68), color: Color.white.opacity(0.4), size: 7)

                // Panel 3: Soil
                let p3x = w * 0.83
                Path { p in
                    p.addRoundedRect(in: CGRect(x: p3x - w * 0.13, y: h * 0.15, width: w * 0.26, height: h * 0.60), cornerSize: CGSize(width: 4, height: 4))
                }
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)

                // Soil mound
                Path { p in
                    p.move(to: CGPoint(x: p3x - 12, y: h * 0.54))
                    p.addQuadCurve(to: CGPoint(x: p3x + 12, y: h * 0.54), control: CGPoint(x: p3x, y: h * 0.40))
                }
                .fill(Color.white.opacity(0.08))
                .overlay(
                    Path { p in
                        p.move(to: CGPoint(x: p3x - 12, y: h * 0.54))
                        p.addQuadCurve(to: CGPoint(x: p3x + 12, y: h * 0.54), control: CGPoint(x: p3x, y: h * 0.40))
                    }
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )

                DiagramLabel("SOIL", at: CGPoint(x: 0.83, y: 0.28), color: accent, size: 9)
                DiagramLabel("LAST RESORT", at: CGPoint(x: 0.83, y: 0.68), color: Color.white.opacity(0.4), size: 7)

                // Title
                DiagramLabel("AFTER EVERY TOILET VISIT", at: CGPoint(x: 0.50, y: 0.08), color: accent, size: 9)
                DiagramLabel("BEST → → → WORST", at: CGPoint(x: 0.50, y: 0.88), color: Color.white.opacity(0.4), size: 8)
            }
        }
    }
}
