import SwiftUI

/// Every icon in the app is drawn here with Canvas paths. No SF Symbols, no emoji,
/// no bitmap assets. The same primitives draw the board objects (see SymbolArt).
enum Glyph: String, CaseIterable {
    case home, chart, trophy, book, gear
    case back, forward, play, pause, close, check, refresh
    case star, plus, minus, calendar, save, restore, info, question
    case palette, heart, heartFilled, clock, target, grid, lock, shuffle, trash, spark, rings
}

struct GlyphArt {

    static func draw(_ glyph: Glyph,
                     in context: inout GraphicsContext,
                     rect r: CGRect,
                     color: Color,
                     weight: CGFloat) {
        let w = weight
        func p(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + r.width * fx, y: r.minY + r.height * fy)
        }
        func stroke(_ path: Path, _ lw: CGFloat? = nil) {
            context.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: lw ?? w, lineCap: .round, lineJoin: .round))
        }
        func fill(_ path: Path) { context.fill(path, with: .color(color)) }
        func poly(_ pts: [CGPoint], closed: Bool = false) -> Path {
            var path = Path()
            guard let first = pts.first else { return path }
            path.move(to: first)
            for pt in pts.dropFirst() { path.addLine(to: pt) }
            if closed { path.closeSubpath() }
            return path
        }
        func circle(_ cx: CGFloat, _ cy: CGFloat, _ rad: CGFloat) -> Path {
            let c = p(cx, cy)
            let radius = rad * min(r.width, r.height)
            return Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius,
                                          width: radius * 2, height: radius * 2))
        }
        func roundRect(_ x: CGFloat, _ y: CGFloat, _ ww: CGFloat, _ hh: CGFloat, _ rad: CGFloat) -> Path {
            Path(roundedRect: CGRect(x: r.minX + r.width * x, y: r.minY + r.height * y,
                                     width: r.width * ww, height: r.height * hh),
                 cornerRadius: rad * min(r.width, r.height))
        }

        switch glyph {
        case .home:
            stroke(poly([p(0.12, 0.48), p(0.5, 0.14), p(0.88, 0.48)]))
            stroke(poly([p(0.22, 0.44), p(0.22, 0.86), p(0.78, 0.86), p(0.78, 0.44)]))
            stroke(poly([p(0.42, 0.86), p(0.42, 0.62), p(0.58, 0.62), p(0.58, 0.86)]))

        case .chart:
            stroke(poly([p(0.12, 0.86), p(0.88, 0.86)]))
            fill(roundRect(0.20, 0.52, 0.13, 0.30, 0.06))
            fill(roundRect(0.435, 0.32, 0.13, 0.50, 0.06))
            fill(roundRect(0.67, 0.44, 0.13, 0.38, 0.06))

        case .trophy:
            stroke(poly([p(0.30, 0.16), p(0.70, 0.16), p(0.66, 0.52), p(0.34, 0.52)], closed: true))
            var lh = Path(); lh.move(to: p(0.30, 0.22)); lh.addQuadCurve(to: p(0.30, 0.44), control: p(0.12, 0.33))
            stroke(lh)
            var rh = Path(); rh.move(to: p(0.70, 0.22)); rh.addQuadCurve(to: p(0.70, 0.44), control: p(0.88, 0.33))
            stroke(rh)
            stroke(poly([p(0.5, 0.52), p(0.5, 0.72)]))
            stroke(poly([p(0.32, 0.84), p(0.68, 0.84)]))
            stroke(poly([p(0.40, 0.72), p(0.60, 0.72)]))

        case .book:
            stroke(roundRect(0.14, 0.18, 0.32, 0.64, 0.06))
            stroke(roundRect(0.54, 0.18, 0.32, 0.64, 0.06))
            stroke(poly([p(0.5, 0.14), p(0.5, 0.86)]))

        case .gear:
            stroke(circle(0.5, 0.5, 0.24))
            stroke(circle(0.5, 0.5, 0.09))
            for i in 0..<6 {
                let a = Double(i) * .pi / 3.0
                let inner = CGPoint(x: p(0.5, 0.5).x + cos(a) * r.width * 0.28,
                                    y: p(0.5, 0.5).y + sin(a) * r.height * 0.28)
                let outer = CGPoint(x: p(0.5, 0.5).x + cos(a) * r.width * 0.42,
                                    y: p(0.5, 0.5).y + sin(a) * r.height * 0.42)
                stroke(poly([inner, outer]))
            }

        case .back:
            stroke(poly([p(0.62, 0.18), p(0.32, 0.5), p(0.62, 0.82)]))

        case .forward:
            stroke(poly([p(0.38, 0.18), p(0.68, 0.5), p(0.38, 0.82)]))

        case .play:
            fill(poly([p(0.30, 0.18), p(0.80, 0.5), p(0.30, 0.82)], closed: true))

        case .pause:
            fill(roundRect(0.30, 0.20, 0.13, 0.60, 0.05))
            fill(roundRect(0.57, 0.20, 0.13, 0.60, 0.05))

        case .close:
            stroke(poly([p(0.24, 0.24), p(0.76, 0.76)]))
            stroke(poly([p(0.76, 0.24), p(0.24, 0.76)]))

        case .check:
            stroke(poly([p(0.20, 0.54), p(0.42, 0.76), p(0.80, 0.26)]))

        case .refresh:
            var arc = Path()
            arc.addArc(center: p(0.5, 0.52), radius: min(r.width, r.height) * 0.30,
                       startAngle: .degrees(-40), endAngle: .degrees(250), clockwise: false)
            stroke(arc)
            stroke(poly([p(0.72, 0.20), p(0.84, 0.40), p(0.62, 0.42)]))

        case .star:
            stroke(starPath(center: p(0.5, 0.52), outer: min(r.width, r.height) * 0.38,
                            inner: min(r.width, r.height) * 0.16, points: 5))

        case .spark:
            fill(starPath(center: p(0.5, 0.5), outer: min(r.width, r.height) * 0.44,
                          inner: min(r.width, r.height) * 0.13, points: 4))

        case .plus:
            stroke(poly([p(0.5, 0.20), p(0.5, 0.80)]))
            stroke(poly([p(0.20, 0.5), p(0.80, 0.5)]))

        case .minus:
            stroke(poly([p(0.20, 0.5), p(0.80, 0.5)]))

        case .calendar:
            stroke(roundRect(0.14, 0.22, 0.72, 0.62, 0.07))
            stroke(poly([p(0.14, 0.40), p(0.86, 0.40)]))
            stroke(poly([p(0.32, 0.14), p(0.32, 0.28)]))
            stroke(poly([p(0.68, 0.14), p(0.68, 0.28)]))
            fill(circle(0.34, 0.58, 0.045))
            fill(circle(0.5, 0.58, 0.045))
            fill(circle(0.66, 0.58, 0.045))
            fill(circle(0.34, 0.73, 0.045))

        case .save:
            stroke(poly([p(0.5, 0.16), p(0.5, 0.58)]))
            stroke(poly([p(0.32, 0.42), p(0.5, 0.60), p(0.68, 0.42)]))
            stroke(poly([p(0.18, 0.70), p(0.18, 0.84), p(0.82, 0.84), p(0.82, 0.70)]))

        case .restore:
            stroke(poly([p(0.5, 0.60), p(0.5, 0.18)]))
            stroke(poly([p(0.32, 0.36), p(0.5, 0.18), p(0.68, 0.36)]))
            stroke(poly([p(0.18, 0.70), p(0.18, 0.84), p(0.82, 0.84), p(0.82, 0.70)]))

        case .info:
            stroke(circle(0.5, 0.5, 0.36))
            fill(circle(0.5, 0.30, 0.055))
            stroke(poly([p(0.5, 0.44), p(0.5, 0.72)]))

        case .question:
            stroke(circle(0.5, 0.5, 0.36))
            var q = Path()
            q.move(to: p(0.36, 0.36))
            q.addQuadCurve(to: p(0.56, 0.48), control: p(0.62, 0.26))
            q.addQuadCurve(to: p(0.5, 0.62), control: p(0.5, 0.55))
            stroke(q)
            fill(circle(0.5, 0.74, 0.05))

        case .palette:
            stroke(circle(0.5, 0.5, 0.36))
            fill(circle(0.36, 0.38, 0.075))
            fill(circle(0.62, 0.36, 0.075))
            fill(circle(0.66, 0.62, 0.075))
            fill(circle(0.38, 0.64, 0.075))

        case .heart, .heartFilled:
            var h = Path()
            h.move(to: p(0.5, 0.80))
            h.addCurve(to: p(0.14, 0.42), control1: p(0.30, 0.68), control2: p(0.14, 0.56))
            h.addArc(center: p(0.32, 0.36), radius: min(r.width, r.height) * 0.185,
                     startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            h.addArc(center: p(0.68, 0.36), radius: min(r.width, r.height) * 0.185,
                     startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            h.addCurve(to: p(0.5, 0.80), control1: p(0.86, 0.56), control2: p(0.70, 0.68))
            if glyph == .heartFilled { fill(h) } else { stroke(h) }

        case .clock:
            stroke(circle(0.5, 0.5, 0.36))
            stroke(poly([p(0.5, 0.5), p(0.5, 0.28)]))
            stroke(poly([p(0.5, 0.5), p(0.68, 0.58)]))

        case .target:
            stroke(circle(0.5, 0.5, 0.40))
            stroke(circle(0.5, 0.5, 0.24))
            fill(circle(0.5, 0.5, 0.08))

        case .grid:
            stroke(roundRect(0.16, 0.16, 0.30, 0.30, 0.05))
            stroke(roundRect(0.54, 0.16, 0.30, 0.30, 0.05))
            stroke(roundRect(0.16, 0.54, 0.30, 0.30, 0.05))
            stroke(roundRect(0.54, 0.54, 0.30, 0.30, 0.05))

        case .lock:
            stroke(roundRect(0.24, 0.46, 0.52, 0.38, 0.08))
            var shackle = Path()
            shackle.addArc(center: p(0.5, 0.46), radius: min(r.width, r.height) * 0.17,
                           startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            stroke(shackle)
            fill(circle(0.5, 0.64, 0.05))

        case .shuffle:
            stroke(poly([p(0.16, 0.30), p(0.44, 0.30), p(0.62, 0.70), p(0.84, 0.70)]))
            stroke(poly([p(0.72, 0.60), p(0.86, 0.70), p(0.72, 0.80)]))
            stroke(poly([p(0.16, 0.70), p(0.36, 0.70)]))
            stroke(poly([p(0.72, 0.20), p(0.86, 0.30), p(0.72, 0.40)]))
            stroke(poly([p(0.62, 0.30), p(0.84, 0.30)]))

        case .trash:
            stroke(poly([p(0.16, 0.30), p(0.84, 0.30)]))
            stroke(poly([p(0.38, 0.30), p(0.40, 0.18), p(0.60, 0.18), p(0.62, 0.30)]))
            stroke(poly([p(0.26, 0.30), p(0.32, 0.84), p(0.68, 0.84), p(0.74, 0.30)]))
            stroke(poly([p(0.44, 0.44), p(0.44, 0.72)]))
            stroke(poly([p(0.56, 0.44), p(0.56, 0.72)]))

        case .rings:
            stroke(circle(0.5, 0.5, 0.44), w * 0.9)
            stroke(circle(0.5, 0.5, 0.30), w * 0.9)
            fill(circle(0.5, 0.5, 0.13))
        }
    }

    static func starPath(center: CGPoint, outer: CGFloat, inner: CGFloat, points: Int) -> Path {
        var path = Path()
        let step = Double.pi / Double(points)
        for i in 0..<(points * 2) {
            let radius = i % 2 == 0 ? outer : inner
            let angle = Double(i) * step - .pi / 2
            let pt = CGPoint(x: center.x + CGFloat(cos(angle)) * radius,
                             y: center.y + CGFloat(sin(angle)) * radius)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

/// Sized, hit-testable icon. Every glyph-only button wraps one of these and adds
/// `.contentShape(Rectangle())` on the sized label.
struct GlyphIcon: View {
    let glyph: Glyph
    var size: CGFloat = 22
    var color: Color = .primary
    var weight: CGFloat = 2

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
            var ctx = context
            GlyphArt.draw(glyph, in: &ctx, rect: rect, color: color, weight: weight)
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

// MARK: - Board object art

enum SymbolArt {

    /// Draws one board object inside `cell`. `screenScale` is the cell edge length
    /// handed down from the board's own geometry — never taken from a Canvas closure.
    static func draw(_ object: GameObject,
                     in context: inout GraphicsContext,
                     cell: CGRect,
                     color: Color,
                     dim: Bool) {
        let scale = object.size.scale
        let side = min(cell.width, cell.height) * scale
        let box = CGRect(x: cell.midX - side / 2, y: cell.midY - side / 2, width: side, height: side)
        let lw = max(1.4, side * 0.13)
        let paint = dim ? color.opacity(0.35) : color

        // Layer level: faint backing rings behind the symbol.
        if object.level != .low {
            for i in 1..<object.level.rings {
                let grow = side * (1.0 + CGFloat(i) * 0.22)
                let ring = CGRect(x: cell.midX - grow / 2, y: cell.midY - grow / 2,
                                  width: grow, height: grow)
                context.stroke(Path(ellipseIn: ring), with: .color(paint.opacity(0.35)),
                               style: StrokeStyle(lineWidth: max(1, lw * 0.6)))
            }
        }

        var ctx = context
        if object.symbol == .chevron || object.symbol == .arc {
            ctx.translateBy(x: cell.midX, y: cell.midY)
            ctx.rotate(by: .radians(object.direction.radians))
            ctx.translateBy(x: -cell.midX, y: -cell.midY)
        }
        drawSymbol(object.symbol, in: &ctx, box: box, color: paint, lineWidth: lw)
    }

    static func drawSymbol(_ symbol: SymbolType,
                           in context: inout GraphicsContext,
                           box: CGRect,
                           color: Color,
                           lineWidth lw: CGFloat) {
        func poly(_ pts: [CGPoint], closed: Bool = true) -> Path {
            var path = Path()
            guard let f = pts.first else { return path }
            path.move(to: f)
            for pt in pts.dropFirst() { path.addLine(to: pt) }
            if closed { path.closeSubpath() }
            return path
        }
        func pt(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
            CGPoint(x: box.minX + box.width * fx, y: box.minY + box.height * fy)
        }
        func stroke(_ path: Path) {
            context.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
        }

        switch symbol {
        case .circle:
            context.fill(Path(ellipseIn: box), with: .color(color))
        case .ring:
            stroke(Path(ellipseIn: box.insetBy(dx: lw / 2, dy: lw / 2)))
        case .square:
            context.fill(Path(roundedRect: box, cornerRadius: box.width * 0.16), with: .color(color))
        case .diamond:
            context.fill(poly([pt(0.5, 0), pt(1, 0.5), pt(0.5, 1), pt(0, 0.5)]), with: .color(color))
        case .triangle:
            context.fill(poly([pt(0.5, 0.04), pt(0.97, 0.92), pt(0.03, 0.92)]), with: .color(color))
        case .chevron:
            stroke(poly([pt(0.10, 0.72), pt(0.5, 0.20), pt(0.90, 0.72)], closed: false))
            stroke(poly([pt(0.10, 0.96), pt(0.5, 0.46), pt(0.90, 0.96)], closed: false))
        case .cross:
            stroke(poly([pt(0.10, 0.10), pt(0.90, 0.90)], closed: false))
            stroke(poly([pt(0.90, 0.10), pt(0.10, 0.90)], closed: false))
        case .star:
            context.fill(GlyphArt.starPath(center: CGPoint(x: box.midX, y: box.midY),
                                           outer: box.width * 0.52,
                                           inner: box.width * 0.22,
                                           points: 5), with: .color(color))
        case .hexagon:
            var pts: [CGPoint] = []
            for i in 0..<6 {
                let a = Double(i) * .pi / 3.0 - .pi / 2
                pts.append(CGPoint(x: box.midX + CGFloat(cos(a)) * box.width * 0.5,
                                   y: box.midY + CGFloat(sin(a)) * box.height * 0.5))
            }
            context.fill(poly(pts), with: .color(color))
        case .arc:
            var path = Path()
            path.addArc(center: CGPoint(x: box.midX, y: box.midY + box.height * 0.22),
                        radius: box.width * 0.48,
                        startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
            stroke(path)
        case .bars:
            let barW = box.width * 0.22
            for i in 0..<3 {
                let x = box.minX + box.width * (0.11 + CGFloat(i) * 0.31)
                let h = box.height * (i == 1 ? 1.0 : 0.68)
                let rect = CGRect(x: x, y: box.midY - h / 2, width: barW, height: h)
                context.fill(Path(roundedRect: rect, cornerRadius: barW * 0.35), with: .color(color))
            }
        case .spiral:
            var path = Path()
            let steps = 44
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let a = t * .pi * 3.2
                let rad = box.width * 0.5 * CGFloat(t)
                let point = CGPoint(x: box.midX + CGFloat(cos(a)) * rad,
                                    y: box.midY + CGFloat(sin(a)) * rad)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            stroke(path)
        }
    }
}

/// Standalone symbol swatch used by palettes and legends.
struct SymbolSwatch: View {
    let symbol: SymbolType
    var direction: Direction = .up
    var level: HeightLevel = .low
    var objectSize: ObjectSize = .large
    var color: Color
    var side: CGFloat = 28

    var body: some View {
        Canvas { context, canvasSize in
            var ctx = context
            let rect = CGRect(origin: .zero, size: canvasSize)
            let object = GameObject(category: .geometric, symbol: symbol, color: .blue,
                                    direction: direction, size: objectSize, level: level)
            SymbolArt.draw(object, in: &ctx, cell: rect, color: color, dim: false)
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
    }
}
