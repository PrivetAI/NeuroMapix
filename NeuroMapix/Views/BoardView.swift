import SwiftUI

/// The board. `side` is always handed in by the caller's GeometryReader — the
/// Canvas closure's own `size` is never used for cell maths.
struct BoardView: View {
    let board: GameBoard
    let side: CGFloat
    let palette: Palette

    var reveal: Bool = true
    var dimmed: Set<Coord> = []
    var selection: [Coord] = []
    var showOrder: Bool = false
    var paintChoices: [Coord: Int] = [:]
    var paintAttribute: PaintAttribute? = nil
    var correctCells: Set<Coord> = []
    var missedCells: Set<Coord> = []
    var wrongCells: Set<Coord> = []
    var showCoordinates: Bool = false
    var enabledCell: (Coord) -> Bool = { _ in true }
    var onTap: ((Coord) -> Void)? = nil

    private var dim: Int { board.size.dimension }
    private var pad: CGFloat { max(4, side * 0.018) }
    private var inner: CGFloat { max(1, side - pad * 2) }
    private var cell: CGFloat { inner / CGFloat(dim) }

    private func rect(_ coord: Coord) -> CGRect {
        CGRect(x: pad + CGFloat(coord.column) * cell,
               y: pad + CGFloat(coord.row) * cell,
               width: cell, height: cell)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                var ctx = context
                draw(&ctx)
            }
            .frame(width: side, height: side)
            .allowsHitTesting(false)

            hitGrid
                .frame(width: inner, height: inner)
                .offset(x: pad, y: pad)
        }
        .frame(width: side, height: side)
    }

    private var hitGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<dim, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<dim, id: \.self) { c in
                        let coord = Coord(r, c)
                        Button {
                            onTap?(coord)
                        } label: {
                            // A clear background is invisible to touches without an
                            // explicit contentShape on the sized label.
                            Color.clear
                                .frame(width: cell, height: cell)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(onTap == nil || !enabledCell(coord))
                    }
                }
            }
        }
    }

    // MARK: - Drawing

    private func draw(_ context: inout GraphicsContext) {
        let full = CGRect(x: 0, y: 0, width: side, height: side)
        context.fill(Path(roundedRect: full, cornerRadius: Metric.cornerM), with: .color(palette.boardBase))

        // Cell plates
        for r in 0..<dim {
            for c in 0..<dim {
                let box = rect(Coord(r, c)).insetBy(dx: cell * 0.045, dy: cell * 0.045)
                context.fill(Path(roundedRect: box, cornerRadius: max(2, cell * 0.14)),
                             with: .color(palette.cellFill))
            }
        }

        // Grid lines
        var lines = Path()
        for i in 0...dim {
            let offset = pad + CGFloat(i) * cell
            lines.move(to: CGPoint(x: pad, y: offset))
            lines.addLine(to: CGPoint(x: pad + inner, y: offset))
            lines.move(to: CGPoint(x: offset, y: pad))
            lines.addLine(to: CGPoint(x: offset, y: pad + inner))
        }
        context.stroke(lines, with: .color(palette.gridLine), lineWidth: 0.7)

        if showCoordinates && cell > 22 {
            let size = max(7, cell * 0.2)
            for i in 0..<dim {
                let label = Text("\(i + 1)")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundColor(palette.textFaint)
                // Column numbers along the top row.
                context.draw(label, at: CGPoint(x: pad + CGFloat(i) * cell + cell * 0.22,
                                                y: pad + cell * 0.18))
                // Row numbers down the left column, skipping the corner cell so the
                // two label sets never overlap.
                if i > 0 {
                    context.draw(label, at: CGPoint(x: pad + cell * 0.18,
                                                    y: pad + CGFloat(i) * cell + cell * 0.22))
                }
            }
        }

        // Objects
        if reveal {
            for r in 0..<dim {
                for c in 0..<dim {
                    let coord = Coord(r, c)
                    guard let object = board.object(at: coord) else { continue }
                    SymbolArt.draw(object, in: &context, cell: rect(coord),
                                   color: palette.color(for: object.color),
                                   dim: dimmed.contains(coord))
                }
            }
        }

        // Painted answers
        if let attribute = paintAttribute {
            for (coord, value) in paintChoices {
                let object = BoardView.paintObject(attribute: attribute, value: value)
                let box = rect(coord)
                context.fill(Path(roundedRect: box.insetBy(dx: cell * 0.08, dy: cell * 0.08),
                                  cornerRadius: max(2, cell * 0.16)),
                             with: .color(palette.primary.opacity(0.14)))
                SymbolArt.draw(object, in: &context, cell: box,
                               color: palette.color(for: object.color), dim: false)
                context.stroke(Path(roundedRect: box.insetBy(dx: cell * 0.06, dy: cell * 0.06),
                                    cornerRadius: max(2, cell * 0.16)),
                               with: .color(palette.primary), lineWidth: max(1.4, cell * 0.05))
            }
        }

        // Selection
        for (index, coord) in selection.enumerated() {
            let box = rect(coord).insetBy(dx: cell * 0.07, dy: cell * 0.07)
            context.fill(Path(roundedRect: box, cornerRadius: max(2, cell * 0.16)),
                         with: .color(palette.primary.opacity(0.26)))
            context.stroke(Path(roundedRect: box, cornerRadius: max(2, cell * 0.16)),
                           with: .color(palette.primary), lineWidth: max(1.4, cell * 0.06))
            if showOrder && cell > 16 {
                let label = Text("\(index + 1)")
                    .font(.system(size: max(9, cell * 0.42), weight: .bold, design: .rounded))
                    .foregroundColor(palette.primary)
                context.draw(label, at: CGPoint(x: box.midX, y: box.midY))
            }
        }

        // Review marks
        for coord in correctCells {
            outline(&context, coord, palette.accent, dash: false)
        }
        for coord in wrongCells {
            outline(&context, coord, palette.error, dash: false)
        }
        for coord in missedCells {
            outline(&context, coord, palette.warning, dash: true)
        }
    }

    private func outline(_ context: inout GraphicsContext, _ coord: Coord, _ color: Color, dash: Bool) {
        let box = rect(coord).insetBy(dx: cell * 0.06, dy: cell * 0.06)
        let path = Path(roundedRect: box, cornerRadius: max(2, cell * 0.16))
        let style = dash
            ? StrokeStyle(lineWidth: max(1.6, cell * 0.06), dash: [cell * 0.18, cell * 0.12])
            : StrokeStyle(lineWidth: max(1.6, cell * 0.07))
        context.stroke(path, with: .color(color), style: style)
    }

    static func paintObject(attribute: PaintAttribute, value: Int) -> GameObject {
        switch attribute {
        case .color:
            return GameObject(category: .geometric, symbol: .circle,
                              color: ColorType(rawValue: value) ?? .blue,
                              direction: .up, size: .medium, level: .low)
        case .symbol:
            return GameObject(category: .geometric, symbol: SymbolType(rawValue: value) ?? .circle,
                              color: .blue, direction: .up, size: .medium, level: .low)
        case .size:
            return GameObject(category: .geometric, symbol: .circle, color: .blue,
                              direction: .up, size: ObjectSize(rawValue: value) ?? .medium, level: .low)
        case .direction:
            return GameObject(category: .kinetic, symbol: .chevron, color: .blue,
                              direction: Direction(rawValue: value) ?? .up, size: .large, level: .low)
        case .level:
            return GameObject(category: .geometric, symbol: .ring, color: .blue,
                              direction: .up, size: .large, level: HeightLevel(rawValue: value) ?? .low)
        case .category:
            let theme = ObjectTheme(rawValue: value) ?? .geometric
            return GameObject(category: theme, symbol: theme.symbols[0], color: theme.colors[0],
                              direction: .up, size: .medium, level: .low)
        }
    }

    static func optionTitle(attribute: PaintAttribute, value: Int) -> String {
        switch attribute {
        case .color: return ColorType(rawValue: value)?.title ?? "-"
        case .symbol: return SymbolType(rawValue: value)?.title ?? "-"
        case .size: return ObjectSize(rawValue: value)?.title ?? "-"
        case .direction: return Direction(rawValue: value)?.title ?? "-"
        case .level: return HeightLevel(rawValue: value)?.title ?? "-"
        case .category: return ObjectTheme(rawValue: value)?.title ?? "-"
        }
    }
}

/// Small non-interactive board thumbnail used in Library / Favorites.
struct BoardThumbnail: View {
    let layout: BoardLayout
    let side: CGFloat
    let palette: Palette

    var body: some View {
        Canvas { context, _ in
            let dim = layout.size.dimension
            let pad: CGFloat = 3
            let inner = side - pad * 2
            let cell = inner / CGFloat(dim)
            context.fill(Path(roundedRect: CGRect(x: 0, y: 0, width: side, height: side),
                              cornerRadius: Metric.cornerS),
                         with: .color(palette.boardBase))
            var lines = Path()
            for i in 0...dim {
                let off = pad + CGFloat(i) * cell
                lines.move(to: CGPoint(x: pad, y: off)); lines.addLine(to: CGPoint(x: pad + inner, y: off))
                lines.move(to: CGPoint(x: off, y: pad)); lines.addLine(to: CGPoint(x: off, y: pad + inner))
            }
            context.stroke(lines, with: .color(palette.gridLine), lineWidth: 0.5)
            for coord in layout.anchors {
                let box = CGRect(x: pad + CGFloat(coord.column) * cell,
                                 y: pad + CGFloat(coord.row) * cell,
                                 width: cell, height: cell).insetBy(dx: cell * 0.22, dy: cell * 0.22)
                context.fill(Path(ellipseIn: box), with: .color(palette.primary))
            }
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
    }
}
