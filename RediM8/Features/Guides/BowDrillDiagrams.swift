import SwiftUI

// MARK: - Bow Drill Fire — 5 Procedural Steps

struct BowDrillDiagrams {

    @ViewBuilder
    static func view(for step: ProceduralDiagramStep, accent: Color) -> some View {
        switch step.id {
        case "bow_drill_1": componentsView(accent: accent)
        case "bow_drill_2": assemblyView(accent: accent)
        case "bow_drill_3": sawingView(accent: accent)
        case "bow_drill_4": emberView(accent: accent)
        case "bow_drill_5": transferView(accent: accent)
        default: EmptyView()
        }
    }

    // MARK: Step 1 — Components

    private static func componentsView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Fireboard — flat rectangle
                Path { p in
                    let x = w * 0.08
                    let y = h * 0.35
                    p.addRoundedRect(in: CGRect(x: x, y: y, width: w * 0.18, height: h * 0.06), cornerSize: CGSize(width: 2, height: 2))
                }
                .fill(Color.white.opacity(0.15))
                .overlay(
                    Path { p in
                        let x = w * 0.08
                        let y = h * 0.35
                        p.addRoundedRect(in: CGRect(x: x, y: y, width: w * 0.18, height: h * 0.06), cornerSize: CGSize(width: 2, height: 2))
                    }
                    .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                )

                // V-notch on fireboard
                Path { p in
                    let cx = w * 0.17
                    let y = h * 0.35
                    p.move(to: CGPoint(x: cx - 4, y: y))
                    p.addLine(to: CGPoint(x: cx, y: y + geo.size.height * 0.03))
                    p.addLine(to: CGPoint(x: cx + 4, y: y))
                }
                .stroke(accent, lineWidth: 1)

                DiagramCallout(text: "FIREBOARD", pointTo: CGPoint(x: 0.17, y: 0.38), labelAt: CGPoint(x: 0.17, y: 0.50), color: Color.white.opacity(0.7))

                // Spindle — vertical stick
                Path { p in
                    let x = w * 0.38
                    p.move(to: CGPoint(x: x, y: h * 0.15))
                    p.addLine(to: CGPoint(x: x, y: h * 0.55))
                }
                .stroke(Color.white.opacity(0.6), lineWidth: 3)

                // Pointed top
                Path { p in
                    let x = w * 0.38
                    p.move(to: CGPoint(x: x - 3, y: h * 0.15))
                    p.addLine(to: CGPoint(x: x, y: h * 0.10))
                    p.addLine(to: CGPoint(x: x + 3, y: h * 0.15))
                }
                .fill(Color.white.opacity(0.6))

                DiagramCallout(text: "SPINDLE", pointTo: CGPoint(x: 0.38, y: 0.35), labelAt: CGPoint(x: 0.38, y: 0.65), color: Color.white.opacity(0.7))

                // Bow — curved line with string
                Path { p in
                    p.move(to: CGPoint(x: w * 0.55, y: h * 0.15))
                    p.addQuadCurve(
                        to: CGPoint(x: w * 0.55, y: h * 0.60),
                        control: CGPoint(x: w * 0.72, y: h * 0.38)
                    )
                }
                .stroke(Color.white.opacity(0.6), lineWidth: 2.5)

                // Bowstring
                Path { p in
                    p.move(to: CGPoint(x: w * 0.55, y: h * 0.15))
                    p.addLine(to: CGPoint(x: w * 0.55, y: h * 0.60))
                }
                .stroke(accent.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))

                DiagramCallout(text: "BOW", pointTo: CGPoint(x: 0.63, y: 0.38), labelAt: CGPoint(x: 0.70, y: 0.25), color: Color.white.opacity(0.7))
                DiagramCallout(text: "STRING", pointTo: CGPoint(x: 0.55, y: 0.38), labelAt: CGPoint(x: 0.70, y: 0.50), color: accent)

                // Bearing block — rounded stone shape
                Path { p in
                    p.addEllipse(in: CGRect(x: w * 0.82, y: h * 0.28, width: w * 0.12, height: h * 0.14))
                }
                .fill(Color.white.opacity(0.1))
                .overlay(
                    Path { p in
                        p.addEllipse(in: CGRect(x: w * 0.82, y: h * 0.28, width: w * 0.12, height: h * 0.14))
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                )

                // Socket dimple
                Path { p in
                    let cx = w * 0.88
                    let cy = h * 0.35
                    p.addArc(center: CGPoint(x: cx, y: cy), radius: 3, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                }
                .stroke(accent, lineWidth: 1)

                DiagramCallout(text: "BEARING\nBLOCK", pointTo: CGPoint(x: 0.88, y: 0.35), labelAt: CGPoint(x: 0.88, y: 0.55), color: Color.white.opacity(0.7))

                // Ground line
                DiagramGroundLine(y: 0.80, xStart: 0.05, xEnd: 0.95)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            }
        }
    }

    // MARK: Step 2 — Assembly

    private static func assemblyView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Ground
                DiagramGroundLine(y: 0.82, xStart: 0.05, xEnd: 0.95)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)

                // Fireboard on ground
                Path { p in
                    p.addRoundedRect(in: CGRect(x: w * 0.20, y: h * 0.74, width: w * 0.55, height: h * 0.06), cornerSize: CGSize(width: 2, height: 2))
                }
                .fill(Color.white.opacity(0.12))
                .overlay(
                    Path { p in
                        p.addRoundedRect(in: CGRect(x: w * 0.20, y: h * 0.74, width: w * 0.55, height: h * 0.06), cornerSize: CGSize(width: 2, height: 2))
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                )

                // V-notch
                Path { p in
                    let cx = w * 0.48
                    let y = h * 0.74
                    p.move(to: CGPoint(x: cx - 5, y: y))
                    p.addLine(to: CGPoint(x: cx, y: y + h * 0.03))
                    p.addLine(to: CGPoint(x: cx + 5, y: y))
                }
                .stroke(accent, lineWidth: 1.5)

                // Spindle — vertical on the board
                Path { p in
                    p.move(to: CGPoint(x: w * 0.48, y: h * 0.22))
                    p.addLine(to: CGPoint(x: w * 0.48, y: h * 0.74))
                }
                .stroke(Color.white.opacity(0.7), lineWidth: 3)

                // Bearing block on top
                Path { p in
                    p.addEllipse(in: CGRect(x: w * 0.42, y: h * 0.14, width: w * 0.12, height: h * 0.10))
                }
                .fill(Color.white.opacity(0.1))
                .overlay(
                    Path { p in
                        p.addEllipse(in: CGRect(x: w * 0.42, y: h * 0.14, width: w * 0.12, height: h * 0.10))
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                )

                // Bow wrapped around spindle
                Path { p in
                    p.move(to: CGPoint(x: w * 0.15, y: h * 0.48))
                    p.addQuadCurve(
                        to: CGPoint(x: w * 0.85, y: h * 0.48),
                        control: CGPoint(x: w * 0.50, y: h * 0.30)
                    )
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 2)

                // String through spindle
                Path { p in
                    p.move(to: CGPoint(x: w * 0.15, y: h * 0.48))
                    p.addLine(to: CGPoint(x: w * 0.45, y: h * 0.48))
                    p.move(to: CGPoint(x: w * 0.51, y: h * 0.48))
                    p.addLine(to: CGPoint(x: w * 0.85, y: h * 0.48))
                }
                .stroke(accent.opacity(0.5), lineWidth: 1)

                // Wrap indicator
                Path { p in
                    let cx = w * 0.48
                    let cy = h * 0.48
                    p.addArc(center: CGPoint(x: cx, y: cy), radius: 6, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
                }
                .stroke(accent, lineWidth: 1.5)

                // Downward pressure arrow
                DiagramArrow(from: CGPoint(x: 0.48, y: 0.04), to: CGPoint(x: 0.48, y: 0.13))
                    .stroke(accent, lineWidth: 1.5)

                DiagramLabel("PRESS DOWN", at: CGPoint(x: 0.48, y: 0.02), color: accent, size: 9)

                DiagramCallout(text: "WRAP ONCE", pointTo: CGPoint(x: 0.48, y: 0.48), labelAt: CGPoint(x: 0.78, y: 0.36), color: accent)
            }
        }
    }

    // MARK: Step 3 — Sawing Motion

    private static func sawingView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Ground
                DiagramGroundLine(y: 0.82, xStart: 0.05, xEnd: 0.95)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)

                // Fireboard
                Path { p in
                    p.addRoundedRect(in: CGRect(x: w * 0.20, y: h * 0.74, width: w * 0.55, height: h * 0.06), cornerSize: CGSize(width: 2, height: 2))
                }
                .stroke(Color.white.opacity(0.4), lineWidth: 1.5)

                // Spindle
                Path { p in
                    p.move(to: CGPoint(x: w * 0.48, y: h * 0.30))
                    p.addLine(to: CGPoint(x: w * 0.48, y: h * 0.74))
                }
                .stroke(Color.white.opacity(0.6), lineWidth: 3)

                // Rotation indicator around spindle
                Path { p in
                    let cx = w * 0.48
                    let cy = h * 0.55
                    p.addArc(center: CGPoint(x: cx, y: cy), radius: 10, startAngle: .degrees(30), endAngle: .degrees(330), clockwise: false)
                }
                .stroke(accent.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))

                // Rotation arrow tip
                DiagramArrow(from: CGPoint(x: 0.51, y: 0.53), to: CGPoint(x: 0.50, y: 0.50))
                    .stroke(accent.opacity(0.5), lineWidth: 1)

                // Bow — horizontal with motion arrows
                Path { p in
                    p.move(to: CGPoint(x: w * 0.10, y: h * 0.50))
                    p.addLine(to: CGPoint(x: w * 0.90, y: h * 0.50))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 2)

                // Double arrow showing reciprocating motion
                DiagramDoubleArrow(y: 0.42, xStart: 0.12, xEnd: 0.88)
                    .stroke(accent, lineWidth: 1.5)

                DiagramLabel("FULL STROKES", at: CGPoint(x: 0.50, y: 0.36), color: accent, size: 10)

                // Downward pressure
                DiagramArrow(from: CGPoint(x: 0.48, y: 0.15), to: CGPoint(x: 0.48, y: 0.28))
                    .stroke(accent.opacity(0.7), lineWidth: 1.5)

                DiagramLabel("PRESSURE", at: CGPoint(x: 0.48, y: 0.10), color: accent.opacity(0.7), size: 9)

                // Speed indicator
                DiagramLabel("MEDIUM SPEED → FAST", at: CGPoint(x: 0.50, y: 0.92), color: Color.white.opacity(0.5), size: 8)
            }
        }
    }

    // MARK: Step 4 — Ember Formation

    private static func emberView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Ground
                DiagramGroundLine(y: 0.82, xStart: 0.05, xEnd: 0.95)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)

                // Fireboard closeup
                Path { p in
                    p.addRoundedRect(in: CGRect(x: w * 0.15, y: h * 0.55, width: w * 0.70, height: h * 0.12), cornerSize: CGSize(width: 3, height: 3))
                }
                .fill(Color.white.opacity(0.08))
                .overlay(
                    Path { p in
                        p.addRoundedRect(in: CGRect(x: w * 0.15, y: h * 0.55, width: w * 0.70, height: h * 0.12), cornerSize: CGSize(width: 3, height: 3))
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                )

                // V-notch (zoomed)
                Path { p in
                    let cx = w * 0.50
                    let top = h * 0.55
                    p.move(to: CGPoint(x: cx - 12, y: top))
                    p.addLine(to: CGPoint(x: cx, y: top + h * 0.08))
                    p.addLine(to: CGPoint(x: cx + 12, y: top))
                }
                .stroke(accent, lineWidth: 2)

                // Ember dust pile below notch
                Path { p in
                    let cx = w * 0.50
                    let y = h * 0.67
                    p.addEllipse(in: CGRect(x: cx - 10, y: y, width: 20, height: 8))
                }
                .fill(ColorTheme.danger.opacity(0.6))

                DiagramCallout(text: "EMBER", pointTo: CGPoint(x: 0.50, y: 0.71), labelAt: CGPoint(x: 0.72, y: 0.75), color: ColorTheme.danger)

                // Smoke rising from notch
                DiagramSmoke(origin: CGPoint(x: 0.50, y: 0.52), color: Color.white)

                // Spindle in notch
                Path { p in
                    p.move(to: CGPoint(x: w * 0.50, y: h * 0.20))
                    p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.55))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 3)

                DiagramCallout(text: "V-NOTCH", pointTo: CGPoint(x: 0.46, y: 0.58), labelAt: CGPoint(x: 0.25, y: 0.45), color: accent)

                DiagramLabel("BLACK DUST = GOOD", at: CGPoint(x: 0.50, y: 0.90), color: Color.white.opacity(0.5), size: 9)
            }
        }
    }

    // MARK: Step 5 — Transfer to Tinder

    private static func transferView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Tinder bundle — nest shape
                Path { p in
                    p.addEllipse(in: CGRect(x: w * 0.55, y: h * 0.30, width: w * 0.32, height: h * 0.30))
                }
                .fill(Color.white.opacity(0.06))
                .overlay(
                    Path { p in
                        p.addEllipse(in: CGRect(x: w * 0.55, y: h * 0.30, width: w * 0.32, height: h * 0.30))
                    }
                    .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                )

                // Texture lines in bundle
                ForEach(0..<5, id: \.self) { i in
                    Path { p in
                        let y = h * (0.38 + CGFloat(i) * 0.04)
                        p.move(to: CGPoint(x: w * 0.60, y: y))
                        p.addQuadCurve(
                            to: CGPoint(x: w * 0.82, y: y),
                            control: CGPoint(x: w * 0.71, y: y + (i % 2 == 0 ? 3 : -3))
                        )
                    }
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                }

                // Ember source (fireboard notch area)
                Path { p in
                    p.addEllipse(in: CGRect(x: w * 0.10, y: h * 0.40, width: 14, height: 8))
                }
                .fill(ColorTheme.danger.opacity(0.7))

                DiagramCallout(text: "EMBER", pointTo: CGPoint(x: 0.12, y: 0.44), labelAt: CGPoint(x: 0.12, y: 0.28), color: ColorTheme.danger)

                // Transfer arrow
                DiagramArrow(from: CGPoint(x: 0.16, y: 0.44), to: CGPoint(x: 0.56, y: 0.44))
                    .stroke(accent, lineWidth: 1.5)

                DiagramLabel("TIP INTO BUNDLE", at: CGPoint(x: 0.36, y: 0.38), color: accent, size: 9)

                // Blow arrow
                DiagramArrow(from: CGPoint(x: 0.50, y: 0.70), to: CGPoint(x: 0.65, y: 0.58))
                    .stroke(Color.white.opacity(0.5), lineWidth: 1.5)

                DiagramLabel("BLOW GENTLY", at: CGPoint(x: 0.50, y: 0.78), color: Color.white.opacity(0.6), size: 9)

                DiagramCallout(text: "TINDER\nBUNDLE", pointTo: CGPoint(x: 0.71, y: 0.45), labelAt: CGPoint(x: 0.88, y: 0.20), color: Color.white.opacity(0.7))

                // Flame indicator at bundle centre
                Path { p in
                    let cx = w * 0.71
                    let cy = h * 0.42
                    p.move(to: CGPoint(x: cx - 3, y: cy + 6))
                    p.addQuadCurve(to: CGPoint(x: cx, y: cy - 8), control: CGPoint(x: cx - 5, y: cy - 2))
                    p.addQuadCurve(to: CGPoint(x: cx + 3, y: cy + 6), control: CGPoint(x: cx + 5, y: cy - 2))
                }
                .stroke(ColorTheme.warning, lineWidth: 1.5)

                DiagramLabel("WRAP LOOSELY · BLOW STEADY", at: CGPoint(x: 0.50, y: 0.92), color: Color.white.opacity(0.5), size: 8)
            }
        }
    }
}
