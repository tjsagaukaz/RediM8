import SwiftUI

// MARK: - Basic Snare Trap — 4 Procedural Steps

struct SnareDiagrams {

    @ViewBuilder
    static func view(for step: ProceduralDiagramStep, accent: Color) -> some View {
        switch step.id {
        case "snare_1": loopView(accent: accent)
        case "snare_2": placementView(accent: accent)
        case "snare_3": funnelView(accent: accent)
        case "snare_4": dragSnareView(accent: accent)
        default: EmptyView()
        }
    }

    // MARK: Step 1 — Loop Construction

    private static func loopView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Wire running up
                Path { p in
                    p.move(to: CGPoint(x: w * 0.50, y: h * 0.85))
                    p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.55))
                }
                .stroke(Color.white.opacity(0.6), lineWidth: 2)

                // Running loop (circle from wire)
                Path { p in
                    p.addEllipse(in: CGRect(x: w * 0.32, y: h * 0.15, width: w * 0.36, height: h * 0.42))
                }
                .stroke(Color.white.opacity(0.7), lineWidth: 2)

                // Knot at junction
                Path { p in
                    p.addEllipse(in: CGRect(x: w * 0.47, y: h * 0.53, width: 10, height: 8))
                }
                .fill(Color.white.opacity(0.3))
                .overlay(
                    Path { p in
                        p.addEllipse(in: CGRect(x: w * 0.47, y: h * 0.53, width: 10, height: 8))
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )

                DiagramCallout(text: "RUNNING\nKNOT", pointTo: CGPoint(x: 0.51, y: 0.56), labelAt: CGPoint(x: 0.78, y: 0.60), color: accent)

                // Fist size reference
                DiagramDimensionLine(
                    from: CGPoint(x: 0.30, y: 0.36),
                    to: CGPoint(x: 0.70, y: 0.36),
                    label: "FIST SIZE",
                    color: accent
                )

                // Arrow showing tightening direction
                DiagramArrow(from: CGPoint(x: 0.62, y: 0.18), to: CGPoint(x: 0.55, y: 0.30))
                    .stroke(accent.opacity(0.5), lineWidth: 1)

                DiagramLabel("TIGHTENS WHEN\nANIMAL PUSHES THROUGH", at: CGPoint(x: 0.50, y: 0.92), color: Color.white.opacity(0.5), size: 8)
            }
        }
    }

    // MARK: Step 2 — Trail Placement

    private static func placementView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Ground
                DiagramGroundLine(y: 0.82, xStart: 0.05, xEnd: 0.95)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)

                // Animal trail (worn path)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.05, y: h * 0.80))
                    p.addQuadCurve(
                        to: CGPoint(x: w * 0.95, y: h * 0.78),
                        control: CGPoint(x: w * 0.50, y: h * 0.72)
                    )
                }
                .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 8, lineCap: .round))

                // Droppings indicators
                ForEach([0.20, 0.35, 0.70], id: \.self) { xFrac in
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 4, height: 4)
                        .position(x: w * CGFloat(xFrac), y: h * 0.76)
                }

                DiagramLabel("TRAIL", at: CGPoint(x: 0.12, y: 0.70), color: Color.white.opacity(0.4), size: 8)

                // Stake in ground
                Path { p in
                    p.move(to: CGPoint(x: w * 0.50, y: h * 0.82))
                    p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.68))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 2.5)

                // Wire from stake up to loop
                Path { p in
                    p.move(to: CGPoint(x: w * 0.50, y: h * 0.68))
                    p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.52))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)

                // Snare loop
                Path { p in
                    p.addEllipse(in: CGRect(x: w * 0.38, y: h * 0.25, width: w * 0.24, height: h * 0.28))
                }
                .stroke(accent, lineWidth: 2)

                // Height dimension (4 fingers)
                DiagramDimensionLine(
                    from: CGPoint(x: 0.72, y: 0.53),
                    to: CGPoint(x: 0.72, y: 0.78),
                    label: "4 FINGERS",
                    color: accent
                )

                DiagramCallout(text: "ANCHOR\nSTAKE", pointTo: CGPoint(x: 0.50, y: 0.75), labelAt: CGPoint(x: 0.25, y: 0.55), color: Color.white.opacity(0.7))

                // Track marks
                ForEach(0..<3, id: \.self) { i in
                    let x = w * (0.55 + CGFloat(i) * 0.10)
                    Path { p in
                        p.move(to: CGPoint(x: x, y: h * 0.76))
                        p.addLine(to: CGPoint(x: x + 3, y: h * 0.73))
                        p.move(to: CGPoint(x: x + 5, y: h * 0.76))
                        p.addLine(to: CGPoint(x: x + 8, y: h * 0.73))
                    }
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                }
            }
        }
    }

    // MARK: Step 3 — Funnel Guide

    private static func funnelView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Ground
                DiagramGroundLine(y: 0.82, xStart: 0.05, xEnd: 0.95)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)

                // Top-down view — trail
                Path { p in
                    p.move(to: CGPoint(x: w * 0.05, y: h * 0.50))
                    p.addLine(to: CGPoint(x: w * 0.95, y: h * 0.50))
                }
                .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 12, lineCap: .round))

                // Funnel sticks — narrowing channel
                // Left side
                Path { p in
                    p.move(to: CGPoint(x: w * 0.25, y: h * 0.28))
                    p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.42))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.30, y: h * 0.26))
                    p.addLine(to: CGPoint(x: w * 0.44, y: h * 0.40))
                }
                .stroke(Color.white.opacity(0.4), lineWidth: 1.5)

                // Right side
                Path { p in
                    p.move(to: CGPoint(x: w * 0.25, y: h * 0.72))
                    p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.58))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.30, y: h * 0.74))
                    p.addLine(to: CGPoint(x: w * 0.44, y: h * 0.60))
                }
                .stroke(Color.white.opacity(0.4), lineWidth: 1.5)

                // Snare loop at narrowing point
                Path { p in
                    p.addEllipse(in: CGRect(x: w * 0.46, y: h * 0.38, width: w * 0.14, height: h * 0.24))
                }
                .stroke(accent, lineWidth: 2)

                DiagramCallout(text: "SNARE", pointTo: CGPoint(x: 0.53, y: 0.50), labelAt: CGPoint(x: 0.75, y: 0.25), color: accent)

                // Direction arrow (animal movement)
                DiagramArrow(from: CGPoint(x: 0.10, y: 0.50), to: CGPoint(x: 0.40, y: 0.50))
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)

                DiagramLabel("ANIMAL →", at: CGPoint(x: 0.10, y: 0.40), color: Color.white.opacity(0.4), size: 8)

                DiagramCallout(text: "FUNNEL\nSTICKS", pointTo: CGPoint(x: 0.35, y: 0.35), labelAt: CGPoint(x: 0.18, y: 0.15), color: Color.white.opacity(0.7))

                DiagramLabel("FORCE THROUGH THE LOOP", at: CGPoint(x: 0.50, y: 0.92), color: accent, size: 9)

                // "TOP VIEW" label
                DiagramLabel("TOP VIEW", at: CGPoint(x: 0.88, y: 0.08), color: Color.white.opacity(0.3), size: 8)
            }
        }
    }

    // MARK: Step 4 — Drag Snare

    private static func dragSnareView(accent: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Ground
                DiagramGroundLine(y: 0.82, xStart: 0.05, xEnd: 0.95)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)

                // Heavy log
                Path { p in
                    p.addRoundedRect(in: CGRect(x: w * 0.60, y: h * 0.62, width: w * 0.28, height: h * 0.12), cornerSize: CGSize(width: 4, height: 4))
                }
                .fill(Color.white.opacity(0.1))
                .overlay(
                    Path { p in
                        p.addRoundedRect(in: CGRect(x: w * 0.60, y: h * 0.62, width: w * 0.28, height: h * 0.12), cornerSize: CGSize(width: 4, height: 4))
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                )

                // Wire from log to snare
                Path { p in
                    p.move(to: CGPoint(x: w * 0.60, y: h * 0.68))
                    p.addLine(to: CGPoint(x: w * 0.40, y: h * 0.55))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)

                // Snare loop
                Path { p in
                    p.addEllipse(in: CGRect(x: w * 0.22, y: h * 0.28, width: w * 0.20, height: h * 0.28))
                }
                .stroke(accent, lineWidth: 2)

                // Drag path (dotted arc showing movement)
                Path { p in
                    p.addArc(
                        center: CGPoint(x: w * 0.50, y: h * 0.50),
                        radius: w * 0.25,
                        startAngle: .degrees(150),
                        endAngle: .degrees(210),
                        clockwise: false
                    )
                }
                .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                DiagramCallout(text: "HEAVY\nLOG", pointTo: CGPoint(x: 0.74, y: 0.68), labelAt: CGPoint(x: 0.80, y: 0.42), color: Color.white.opacity(0.7))
                DiagramCallout(text: "WIRE", pointTo: CGPoint(x: 0.50, y: 0.61), labelAt: CGPoint(x: 0.50, y: 0.80), color: Color.white.opacity(0.5))

                // "NOT FIXED" emphasis
                DiagramLabel("NOT FIXED — ANIMAL DRAGS + TIRES", at: CGPoint(x: 0.50, y: 0.92), color: accent, size: 8)

                // vs comparison
                Path { p in
                    p.move(to: CGPoint(x: w * 0.50, y: h * 0.10))
                    p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.20))
                }
                .stroke(accent.opacity(0.3), lineWidth: 0.5)

                DiagramLabel("FOR LARGER GAME", at: CGPoint(x: 0.50, y: 0.08), color: accent.opacity(0.6), size: 9)
            }
        }
    }
}
