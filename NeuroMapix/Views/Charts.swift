import SwiftUI

/// All charts are drawn by hand with Canvas — no charting framework is linked.

struct TrendChart: View {
    let values: [Double]
    let palette: Palette
    var tint: Color
    var height: CGFloat = 132
    var maxOverride: Double? = nil

    var body: some View {
        Canvas { context, size in
            let plot = CGRect(x: 8, y: 8, width: size.width - 16, height: size.height - 24)
            let top = maxOverride ?? max(values.max() ?? 1, 1)
            let bottom = 0.0

            // baseline + guides
            var guides = Path()
            for i in 0...3 {
                let y = plot.minY + plot.height * CGFloat(i) / 3.0
                guides.move(to: CGPoint(x: plot.minX, y: y))
                guides.addLine(to: CGPoint(x: plot.maxX, y: y))
            }
            context.stroke(guides, with: .color(palette.gridLine), lineWidth: 0.6)

            guard values.count > 1 else {
                let label = Text("Not enough sessions yet")
                    .font(AppFont.caption).foregroundColor(palette.textFaint)
                context.draw(label, at: CGPoint(x: plot.midX, y: plot.midY))
                return
            }

            func point(_ index: Int) -> CGPoint {
                let x = plot.minX + plot.width * CGFloat(index) / CGFloat(values.count - 1)
                let ratio = (values[index] - bottom) / max(0.0001, top - bottom)
                let y = plot.maxY - plot.height * CGFloat(min(1, max(0, ratio)))
                return CGPoint(x: x, y: y)
            }

            var area = Path()
            area.move(to: CGPoint(x: point(0).x, y: plot.maxY))
            for i in values.indices { area.addLine(to: point(i)) }
            area.addLine(to: CGPoint(x: point(values.count - 1).x, y: plot.maxY))
            area.closeSubpath()
            context.fill(area, with: .linearGradient(
                Gradient(colors: [tint.opacity(0.32), tint.opacity(0.02)]),
                startPoint: CGPoint(x: plot.midX, y: plot.minY),
                endPoint: CGPoint(x: plot.midX, y: plot.maxY)))

            var line = Path()
            line.move(to: point(0))
            for i in values.indices.dropFirst() { line.addLine(to: point(i)) }
            context.stroke(line, with: .color(tint),
                           style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

            for i in values.indices {
                let p = point(i)
                let dot = CGRect(x: p.x - 2.6, y: p.y - 2.6, width: 5.2, height: 5.2)
                context.fill(Path(ellipseIn: dot), with: .color(tint))
            }

            let maxLabel = Text("\(Int(top))").font(AppFont.caption).foregroundColor(palette.textFaint)
            context.draw(maxLabel, at: CGPoint(x: plot.minX + 14, y: plot.minY - 2))
            let countLabel = Text("last \(values.count)")
                .font(AppFont.caption).foregroundColor(palette.textFaint)
            context.draw(countLabel, at: CGPoint(x: plot.maxX - 22, y: plot.maxY + 12))
        }
        .frame(height: height)
    }
}

struct RankedBarChart: View {
    let items: [(label: String, value: Double, caption: String)]
    let palette: Palette
    var tint: Color
    var rowHeight: CGFloat = 26

    var body: some View {
        let top = max(items.map { $0.value }.max() ?? 1, 0.0001)
        return VStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { pair in
                let item = pair.element
                HStack(spacing: Metric.spaceS) {
                    Text(item.label)
                        .font(AppFont.caption)
                        .foregroundColor(palette.text)
                        .frame(width: 78, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(palette.gridLine.opacity(0.6))
                                .frame(height: 10)
                            Capsule().fill(tint)
                                .frame(width: max(4, geo.size.width * CGFloat(item.value / top)),
                                       height: 10)
                        }
                        .frame(height: geo.size.height, alignment: .center)
                    }
                    .frame(height: rowHeight - 10)
                    Text(item.caption)
                        .font(AppFont.captionBold)
                        .foregroundColor(palette.textSoft)
                        .frame(width: 52, alignment: .trailing)
                }
                .frame(height: rowHeight)
            }
        }
    }
}

struct ColumnChart: View {
    let items: [(label: String, value: Double)]
    let palette: Palette
    var tint: Color
    var height: CGFloat = 118

    var body: some View {
        Canvas { context, size in
            guard !items.isEmpty else { return }
            let plot = CGRect(x: 4, y: 6, width: size.width - 8, height: size.height - 26)
            let top = max(items.map { $0.value }.max() ?? 1, 0.0001)
            let slot = plot.width / CGFloat(items.count)
            let barWidth = min(slot * 0.62, 34)

            var base = Path()
            base.move(to: CGPoint(x: plot.minX, y: plot.maxY))
            base.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
            context.stroke(base, with: .color(palette.gridLine), lineWidth: 0.8)

            for (i, item) in items.enumerated() {
                let cx = plot.minX + slot * (CGFloat(i) + 0.5)
                let h = plot.height * CGFloat(item.value / top)
                let rect = CGRect(x: cx - barWidth / 2, y: plot.maxY - max(2, h),
                                  width: barWidth, height: max(2, h))
                context.fill(Path(roundedRect: rect, cornerRadius: 4),
                             with: .color(item.value > 0 ? tint : palette.gridLine))
                let label = Text(item.label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(palette.textFaint)
                context.draw(label, at: CGPoint(x: cx, y: plot.maxY + 10))
                if item.value > 0 {
                    // Keep the value inside the plot: above the bar when there is
                    // room, otherwise just inside its top edge.
                    let above = rect.minY - 7
                    let inside = above < plot.minY + 4
                    let v = Text("\(Int(item.value))")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(inside ? .white : palette.textSoft)
                    context.draw(v, at: CGPoint(x: cx, y: inside ? rect.minY + 9 : above))
                }
            }
        }
        .frame(height: height)
    }
}

struct AccuracyDial: View {
    let value: Double
    let palette: Palette
    var side: CGFloat = 92

    var body: some View {
        ProgressRing(progress: value,
                     lineWidth: 9,
                     color: palette.accent,
                     track: palette.accent.opacity(0.14),
                     side: side,
                     centerText: "\(Int(round(value * 100)))%",
                     caption: "AVERAGE",
                     textColor: palette.text)
    }
}
