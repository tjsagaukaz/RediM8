import SwiftUI

// MARK: - Diagram Primitives

/// Reusable drawing primitives for procedural survival diagrams.
/// All coordinates are proportional (0–1) and scale to any container size.

// MARK: Arrow

struct DiagramArrow: Shape {
    let from: CGPoint
    let to: CGPoint
    let headLength: CGFloat

    init(from: CGPoint, to: CGPoint, headLength: CGFloat = 8) {
        self.from = from
        self.to = to
        self.headLength = headLength
    }

    func path(in rect: CGRect) -> Path {
        let start = CGPoint(x: from.x * rect.width, y: from.y * rect.height)
        let end = CGPoint(x: to.x * rect.width, y: to.y * rect.height)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let hl = headLength

        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        // Arrowhead
        path.move(to: end)
        path.addLine(to: CGPoint(
            x: end.x - hl * cos(angle - .pi / 6),
            y: end.y - hl * sin(angle - .pi / 6)
        ))
        path.move(to: end)
        path.addLine(to: CGPoint(
            x: end.x - hl * cos(angle + .pi / 6),
            y: end.y - hl * sin(angle + .pi / 6)
        ))

        return path
    }
}

// MARK: Double Arrow (reciprocating motion)

struct DiagramDoubleArrow: Shape {
    let y: CGFloat
    let xStart: CGFloat
    let xEnd: CGFloat

    func path(in rect: CGRect) -> Path {
        let sy = y * rect.height
        let sx = xStart * rect.width
        let ex = xEnd * rect.width
        let hl: CGFloat = 7

        var path = Path()
        // Left arrow
        path.move(to: CGPoint(x: ex, y: sy))
        path.addLine(to: CGPoint(x: sx, y: sy))
        path.addLine(to: CGPoint(x: sx + hl, y: sy - hl * 0.5))
        path.move(to: CGPoint(x: sx, y: sy))
        path.addLine(to: CGPoint(x: sx + hl, y: sy + hl * 0.5))
        // Right arrow
        path.move(to: CGPoint(x: sx, y: sy))
        path.addLine(to: CGPoint(x: ex, y: sy))
        path.addLine(to: CGPoint(x: ex - hl, y: sy - hl * 0.5))
        path.move(to: CGPoint(x: ex, y: sy))
        path.addLine(to: CGPoint(x: ex - hl, y: sy + hl * 0.5))

        return path
    }
}

// MARK: Dimension Line

struct DiagramDimensionLine: View {
    let from: CGPoint
    let to: CGPoint
    let label: String
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let start = CGPoint(x: from.x * geo.size.width, y: from.y * geo.size.height)
            let end = CGPoint(x: to.x * geo.size.width, y: to.y * geo.size.height)
            let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)

            ZStack {
                // Dashed line
                Path { path in
                    path.move(to: start)
                    path.addLine(to: end)
                }
                .stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                // End ticks
                Path { path in
                    let isHorizontal = abs(end.y - start.y) < abs(end.x - start.x)
                    if isHorizontal {
                        path.move(to: CGPoint(x: start.x, y: start.y - 4))
                        path.addLine(to: CGPoint(x: start.x, y: start.y + 4))
                        path.move(to: CGPoint(x: end.x, y: end.y - 4))
                        path.addLine(to: CGPoint(x: end.x, y: end.y + 4))
                    } else {
                        path.move(to: CGPoint(x: start.x - 4, y: start.y))
                        path.addLine(to: CGPoint(x: start.x + 4, y: start.y))
                        path.move(to: CGPoint(x: end.x - 4, y: end.y))
                        path.addLine(to: CGPoint(x: end.x + 4, y: end.y))
                    }
                }
                .stroke(color.opacity(0.5), lineWidth: 1)

                // Label
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(ColorTheme.panel.opacity(0.9))
                    .position(mid)
            }
        }
    }
}

// MARK: Part Label

struct DiagramLabel: View {
    let text: String
    let position: CGPoint
    let anchor: UnitPoint
    let color: Color
    let size: CGFloat

    init(
        _ text: String,
        at position: CGPoint,
        anchor: UnitPoint = .center,
        color: Color = ColorTheme.text,
        size: CGFloat = 10
    ) {
        self.text = text
        self.position = position
        self.anchor = anchor
        self.color = color
        self.size = size
    }

    var body: some View {
        GeometryReader { geo in
            Text(text)
                .font(.system(size: size, weight: .semibold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(color)
                .fixedSize()
                .position(
                    x: position.x * geo.size.width,
                    y: position.y * geo.size.height
                )
        }
    }
}

// MARK: Callout Label (with leader line)

struct DiagramCallout: View {
    let text: String
    let pointTo: CGPoint
    let labelAt: CGPoint
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let target = CGPoint(x: pointTo.x * geo.size.width, y: pointTo.y * geo.size.height)
            let label = CGPoint(x: labelAt.x * geo.size.width, y: labelAt.y * geo.size.height)

            ZStack {
                // Leader line
                Path { path in
                    path.move(to: label)
                    path.addLine(to: target)
                }
                .stroke(color.opacity(0.4), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))

                // Dot at target
                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)
                    .position(target)

                // Label
                Text(text)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(color)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(ColorTheme.panel)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .stroke(color.opacity(0.3), lineWidth: 0.5)
                            )
                    )
                    .position(label)
            }
        }
    }
}

// MARK: Ground Line

struct DiagramGroundLine: Shape {
    let y: CGFloat
    let xStart: CGFloat
    let xEnd: CGFloat

    func path(in rect: CGRect) -> Path {
        let sy = y * rect.height
        var path = Path()
        path.move(to: CGPoint(x: xStart * rect.width, y: sy))
        path.addLine(to: CGPoint(x: xEnd * rect.width, y: sy))

        // Hash marks for ground
        let count = 8
        let span = (xEnd - xStart) * rect.width
        let spacing = span / CGFloat(count)
        for i in 0..<count {
            let x = xStart * rect.width + CGFloat(i) * spacing + spacing * 0.5
            path.move(to: CGPoint(x: x, y: sy))
            path.addLine(to: CGPoint(x: x - 4, y: sy + 6))
        }

        return path
    }
}

// MARK: Smoke Effect

struct DiagramSmoke: View {
    let origin: CGPoint
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let x = origin.x * geo.size.width
            let y = origin.y * geo.size.height

            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Path { path in
                        let offset = CGFloat(i) * 6
                        let sway = CGFloat(i % 2 == 0 ? 1 : -1) * 4
                        path.move(to: CGPoint(x: x + sway, y: y - offset))
                        path.addQuadCurve(
                            to: CGPoint(x: x - sway, y: y - offset - 14),
                            control: CGPoint(x: x + sway * 2, y: y - offset - 7)
                        )
                    }
                    .stroke(color.opacity(0.3 - Double(i) * 0.08), lineWidth: 1.5)
                }
            }
        }
    }
}

// MARK: Cross-Section Fill (hatching)

struct DiagramHatching: Shape {
    let rect: CGRect
    let spacing: CGFloat
    let angle: CGFloat

    init(in rect: CGRect, spacing: CGFloat = 6, angle: CGFloat = .pi / 4) {
        self.rect = rect
        self.spacing = spacing
        self.angle = angle
    }

    func path(in drawRect: CGRect) -> Path {
        let scaledRect = CGRect(
            x: rect.origin.x * drawRect.width,
            y: rect.origin.y * drawRect.height,
            width: rect.size.width * drawRect.width,
            height: rect.size.height * drawRect.height
        )

        var path = Path()
        let diagonal = sqrt(scaledRect.width * scaledRect.width + scaledRect.height * scaledRect.height)
        let count = Int(diagonal / spacing)

        for i in 0...count {
            let offset = CGFloat(i) * spacing - diagonal / 2
            let dx = cos(angle) * diagonal
            let dy = sin(angle) * diagonal
            let cx = scaledRect.midX
            let cy = scaledRect.midY

            let start = CGPoint(x: cx + offset * cos(angle + .pi / 2) - dx / 2, y: cy + offset * sin(angle + .pi / 2) - dy / 2)
            let end = CGPoint(x: cx + offset * cos(angle + .pi / 2) + dx / 2, y: cy + offset * sin(angle + .pi / 2) + dy / 2)

            // Clip to rect
            if scaledRect.contains(start) || scaledRect.contains(end)
                || lineIntersectsRect(start: start, end: end, rect: scaledRect) {
                path.move(to: clamp(start, to: scaledRect))
                path.addLine(to: clamp(end, to: scaledRect))
            }
        }

        return path
    }

    private func clamp(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    private func lineIntersectsRect(start: CGPoint, end: CGPoint, rect: CGRect) -> Bool {
        start.x <= rect.maxX && end.x >= rect.minX && start.y <= rect.maxY && end.y >= rect.minY
    }
}

// MARK: Step Diagram Container

struct StepDiagramContainer: View {
    let stepNumber: Int
    let title: String
    let focusLabel: String
    let highlightedParts: [String]
    let accent: Color
    let content: AnyView

    @ScaledMetric(relativeTo: .caption) private var headerFontSize: CGFloat = 10
    @ScaledMetric(relativeTo: .caption) private var focusFontSize: CGFloat = 11
    @ScaledMetric(relativeTo: .caption2) private var headerDividerHeight: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var diagramHeight: CGFloat = 200

    init(
        stepNumber: Int,
        title: String,
        focusLabel: String,
        highlightedParts: [String] = [],
        accent: Color,
        @ViewBuilder content: () -> some View
    ) {
        self.stepNumber = stepNumber
        self.title = title
        self.focusLabel = focusLabel
        self.highlightedParts = highlightedParts
        self.accent = accent
        self.content = AnyView(content())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header strip
            HStack(spacing: 8) {
                Text("STEP \(stepNumber)")
                    .font(.system(size: headerFontSize, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(accent)

                Rectangle()
                    .fill(accent.opacity(0.3))
                    .frame(width: 1, height: headerDividerHeight)

                Text(title)
                    .font(.system(size: headerFontSize, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(ColorTheme.text)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ColorTheme.graphite)

            // Focus label
            Text(focusLabel)
                .font(.system(size: focusFontSize, weight: .semibold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(accent)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // Diagram canvas
            content
                .frame(height: diagramHeight)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .accessibilityHidden(true)
        }
        .background(ColorTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(stepNumber): \(title). Focus: \(focusLabel).")
        .accessibilityValue(highlightedPartsDescription)
    }

    private var highlightedPartsDescription: String {
        guard !highlightedParts.isEmpty else {
            return "Visual reference."
        }

        let parts = highlightedParts
            .map { $0.replacingOccurrences(of: "_", with: " ") }
            .joined(separator: ", ")
        return "Highlights: \(parts)."
    }
}
