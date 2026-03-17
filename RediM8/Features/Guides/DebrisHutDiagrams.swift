import SwiftUI

// MARK: - Debris Hut Shelter — 5 Procedural Steps

struct DebrisHutDiagrams {

    @ViewBuilder
    static func view(for step: ProceduralDiagramStep, accent: Color) -> some View {
        switch step.id {
        case "debris_hut_1": ridgepoleView(accent: accent)
        case "debris_hut_2": ribStructureView(accent: accent)
        case "debris_hut_3": latticeView(accent: accent)
        case "debris_hut_4": insulationView(accent: accent)
        case "debris_hut_5": entranceView(accent: accent)
        default: EmptyView()
        }
    }

    // MARK: Step 1 — Ridgepole

    private static func ridgepoleView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Ground
                DiagramGroundLine(y: 0.82, xStart: 0.05, xEnd: 0.95)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)

                // Support fork (Y-shaped)
                Path { p in
                    let bx = w * 0.25
                    let by = h * 0.82
                    p.move(to: CGPoint(x: bx, y: by))
                    p.addLine(to: CGPoint(x: bx, y: h * 0.45))
                    p.move(to: CGPoint(x: bx, y: h * 0.45))
                    p.addLine(to: CGPoint(x: bx - 8, y: h * 0.35))
                    p.move(to: CGPoint(x: bx, y: h * 0.45))
                    p.addLine(to: CGPoint(x: bx + 8, y: h * 0.35))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 2)

                // Ridgepole — angled beam
                Path { p in
                    p.move(to: CGPoint(x: w * 0.25, y: h * 0.40))
                    p.addLine(to: CGPoint(x: w * 0.85, y: h * 0.80))
                }
                .stroke(Color.white.opacity(0.7), lineWidth: 3)

                // Height dimension
                DiagramDimensionLine(
                    from: CGPoint(x: 0.18, y: 0.40),
                    to: CGPoint(x: 0.18, y: 0.82),
                    label: "WAIST",
                    color: accent
                )

                // Length dimension
                DiagramDimensionLine(
                    from: CGPoint(x: 0.25, y: 0.90),
                    to: CGPoint(x: 0.85, y: 0.90),
                    label: "2.5–3M",
                    color: accent
                )

                DiagramCallout(text: "RIDGEPOLE", pointTo: CGPoint(x: 0.55, y: 0.60), labelAt: CGPoint(x: 0.55, y: 0.25), color: Color.white.opacity(0.7))
                DiagramCallout(text: "FORK", pointTo: CGPoint(x: 0.25, y: 0.42), labelAt: CGPoint(x: 0.40, y: 0.18), color: accent)
            }
        }
    }

    // MARK: Step 2 — Rib Structure

    private static func ribStructureView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Ground
                DiagramGroundLine(y: 0.82, xStart: 0.05, xEnd: 0.95)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)

                // Ridgepole (fainter)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.20, y: h * 0.30))
                    p.addLine(to: CGPoint(x: w * 0.85, y: h * 0.78))
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 2)

                // Rib sticks — pairs along ridgepole
                ForEach(0..<6, id: \.self) { i in
                    let t = CGFloat(i) / 6.0
                    let cx = w * (0.28 + t * 0.50)
                    let cy = h * (0.34 + t * 0.38)
                    let ribLen = h * 0.22 * (1 - t * 0.4)

                    // Left rib
                    Path { p in
                        p.move(to: CGPoint(x: cx, y: cy))
                        p.addLine(to: CGPoint(x: cx - ribLen * 0.7, y: h * 0.80))
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)

                    // Right rib
                    Path { p in
                        p.move(to: CGPoint(x: cx, y: cy))
                        p.addLine(to: CGPoint(x: cx + ribLen * 0.7, y: h * 0.80))
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                }

                // Angle indicator on first rib
                Path { p in
                    let cx = w * 0.28
                    let cy = h * 0.34
                    p.addArc(center: CGPoint(x: cx, y: cy), radius: 16, startAngle: .degrees(60), endAngle: .degrees(90), clockwise: false)
                }
                .stroke(accent, lineWidth: 1)

                DiagramLabel("30°", at: CGPoint(x: 0.22, y: 0.42), color: accent, size: 9)

                // Spacing indicator
                DiagramDimensionLine(
                    from: CGPoint(x: 0.28, y: 0.88),
                    to: CGPoint(x: 0.37, y: 0.88),
                    label: "30CM",
                    color: accent
                )

                DiagramCallout(text: "RIB STICKS", pointTo: CGPoint(x: 0.35, y: 0.55), labelAt: CGPoint(x: 0.60, y: 0.18), color: Color.white.opacity(0.7))
            }
        }
    }

    // MARK: Step 3 — Lattice Layer

    private static func latticeView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Ground
                DiagramGroundLine(y: 0.82, xStart: 0.05, xEnd: 0.95)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)

                // Shelter outline (triangle shape)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.20, y: h * 0.28))
                    p.addLine(to: CGPoint(x: w * 0.08, y: h * 0.80))
                    p.addLine(to: CGPoint(x: w * 0.80, y: h * 0.80))
                    p.addLine(to: CGPoint(x: w * 0.20, y: h * 0.28))
                    p.move(to: CGPoint(x: w * 0.20, y: h * 0.28))
                    p.addLine(to: CGPoint(x: w * 0.35, y: h * 0.80))
                }
                .stroke(Color.white.opacity(0.25), lineWidth: 1.5)

                // Cross-hatching for lattice (smaller sticks across ribs)
                ForEach(0..<8, id: \.self) { i in
                    let y = h * (0.38 + CGFloat(i) * 0.05)
                    let leftX = w * (0.13 + CGFloat(i) * 0.02)
                    let rightX = w * (0.55 - CGFloat(i) * 0.03)

                    Path { p in
                        p.move(to: CGPoint(x: leftX, y: y))
                        p.addLine(to: CGPoint(x: rightX, y: y))
                    }
                    .stroke(accent.opacity(0.3), lineWidth: 1)
                }

                DiagramCallout(text: "LATTICE", pointTo: CGPoint(x: 0.30, y: 0.50), labelAt: CGPoint(x: 0.65, y: 0.25), color: accent)
                DiagramLabel("SMALL STICKS + BRUSH", at: CGPoint(x: 0.50, y: 0.92), color: Color.white.opacity(0.5), size: 8)
            }
        }
    }

    // MARK: Step 4 — Insulation

    private static func insulationView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Ground
                DiagramGroundLine(y: 0.82, xStart: 0.05, xEnd: 0.95)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)

                // Outer insulation mound (large organic shape)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.05, y: h * 0.80))
                    p.addQuadCurve(to: CGPoint(x: w * 0.22, y: h * 0.18), control: CGPoint(x: w * 0.05, y: h * 0.40))
                    p.addQuadCurve(to: CGPoint(x: w * 0.82, y: h * 0.80), control: CGPoint(x: w * 0.50, y: h * 0.12))
                }
                .fill(Color.white.opacity(0.06))
                .overlay(
                    Path { p in
                        p.move(to: CGPoint(x: w * 0.05, y: h * 0.80))
                        p.addQuadCurve(to: CGPoint(x: w * 0.22, y: h * 0.18), control: CGPoint(x: w * 0.05, y: h * 0.40))
                        p.addQuadCurve(to: CGPoint(x: w * 0.82, y: h * 0.80), control: CGPoint(x: w * 0.50, y: h * 0.12))
                    }
                    .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                )

                // Inner structure outline (shows wall thickness)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.12, y: h * 0.78))
                    p.addLine(to: CGPoint(x: w * 0.24, y: h * 0.32))
                    p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.78))
                }
                .stroke(Color.white.opacity(0.25), lineWidth: 1)

                // Thickness dimension (wall)
                DiagramDimensionLine(
                    from: CGPoint(x: 0.68, y: 0.50),
                    to: CGPoint(x: 0.78, y: 0.45),
                    label: "60CM+",
                    color: accent
                )

                // Ground insulation inside
                Path { p in
                    p.addRect(CGRect(x: w * 0.18, y: h * 0.68, width: w * 0.48, height: h * 0.10))
                }
                .fill(accent.opacity(0.1))
                .overlay(
                    Path { p in
                        p.addRect(CGRect(x: w * 0.18, y: h * 0.68, width: w * 0.48, height: h * 0.10))
                    }
                    .stroke(accent.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                )

                DiagramCallout(text: "GROUND\nINSULATION", pointTo: CGPoint(x: 0.42, y: 0.73), labelAt: CGPoint(x: 0.42, y: 0.92), color: accent)
                DiagramCallout(text: "DEBRIS\n60CM+ THICK", pointTo: CGPoint(x: 0.40, y: 0.25), labelAt: CGPoint(x: 0.70, y: 0.18), color: Color.white.opacity(0.7))

                DiagramLabel("THICKER = WARMER", at: CGPoint(x: 0.50, y: 0.06), color: Color.white.opacity(0.5), size: 9)
            }
        }
    }

    // MARK: Step 5 — Entrance Seal

    private static func entranceView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Ground
                DiagramGroundLine(y: 0.82, xStart: 0.05, xEnd: 0.95)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)

                // Shelter profile (side view, entrance on left)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.10, y: h * 0.78))
                    p.addQuadCurve(to: CGPoint(x: w * 0.30, y: h * 0.22), control: CGPoint(x: w * 0.10, y: h * 0.40))
                    p.addQuadCurve(to: CGPoint(x: w * 0.88, y: h * 0.78), control: CGPoint(x: w * 0.58, y: h * 0.15))
                }
                .fill(Color.white.opacity(0.05))
                .overlay(
                    Path { p in
                        p.move(to: CGPoint(x: w * 0.10, y: h * 0.78))
                        p.addQuadCurve(to: CGPoint(x: w * 0.30, y: h * 0.22), control: CGPoint(x: w * 0.10, y: h * 0.40))
                        p.addQuadCurve(to: CGPoint(x: w * 0.88, y: h * 0.78), control: CGPoint(x: w * 0.58, y: h * 0.15))
                    }
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )

                // Entrance opening
                Path { p in
                    p.move(to: CGPoint(x: w * 0.10, y: h * 0.78))
                    p.addLine(to: CGPoint(x: w * 0.10, y: h * 0.50))
                    p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.42))
                }
                .stroke(accent, lineWidth: 2)

                // Door plug (debris bundle)
                Path { p in
                    p.addEllipse(in: CGRect(x: w * 0.04, y: h * 0.45, width: w * 0.12, height: h * 0.28))
                }
                .fill(accent.opacity(0.1))
                .overlay(
                    Path { p in
                        p.addEllipse(in: CGRect(x: w * 0.04, y: h * 0.45, width: w * 0.12, height: h * 0.28))
                    }
                    .stroke(accent.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                )

                DiagramCallout(text: "PLUG", pointTo: CGPoint(x: 0.10, y: 0.58), labelAt: CGPoint(x: 0.10, y: 0.25), color: accent)

                // Person silhouette inside (simple)
                Path { p in
                    // Head
                    p.addEllipse(in: CGRect(x: w * 0.52, y: h * 0.50, width: 10, height: 10))
                    // Body line
                    p.move(to: CGPoint(x: w * 0.52 + 5, y: h * 0.60))
                    p.addLine(to: CGPoint(x: w * 0.35, y: h * 0.72))
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)

                // Body space label
                DiagramCallout(text: "BODY\nSIZE ONLY", pointTo: CGPoint(x: 0.45, y: 0.60), labelAt: CGPoint(x: 0.72, y: 0.35), color: Color.white.opacity(0.5))

                DiagramLabel("SMALL = WARM · LARGE = COLD", at: CGPoint(x: 0.50, y: 0.92), color: Color.white.opacity(0.5), size: 8)
            }
        }
    }
}
