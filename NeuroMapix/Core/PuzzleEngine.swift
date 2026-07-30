import Foundation

// MARK: - Interaction

enum Interaction {
    /// Unordered set of cells. `showExpected == false` hides the target count.
    case tapCells(expected: Int, maxSelections: Int, showExpected: Bool)
    /// Ordered taps, order graded position by position.
    case tapOrdered(expected: Int)
    /// Ordered taps constrained to orthogonally adjacent cells.
    case tapPath(expected: Int)
    /// Assign an attribute value to each remembered cell.
    case paint(attribute: PaintAttribute, options: [Int], expected: Int, maxSelections: Int)

    var expected: Int {
        switch self {
        case .tapCells(let e, _, _): return e
        case .tapOrdered(let e): return e
        case .tapPath(let e): return e
        case .paint(_, _, let e, _): return e
        }
    }

    var maxSelections: Int {
        switch self {
        case .tapCells(_, let m, _): return m
        case .tapOrdered(let e): return e
        case .tapPath(let e): return e
        case .paint(_, _, _, let m): return m
        }
    }

    var showExpected: Bool {
        if case .tapCells(_, _, let show) = self { return show }
        return true
    }

    var isPaint: Bool { if case .paint = self { return true }; return false }
}

// MARK: - Stage / Puzzle

struct PuzzleStage: Identifiable {
    let id = UUID()
    var frames: [GameBoard]
    var frameInterval: Double
    var previewSeconds: Double
    var recallBoard: GameBoard?
    var solution: Solution
    var interaction: Interaction
    var previewPrompt: String
    var recallPrompt: String
    /// When true the stage skips its own preview and reuses the previous one.
    var sharedPreview: Bool = false

    var lastFrame: GameBoard { frames.last ?? frames[0] }
}

struct Puzzle {
    var mode: GameModeType
    var difficulty: Int
    var size: BoardSize
    var layoutID: Int
    var layoutName: String
    var stages: [PuzzleStage]
    var timeLimit: Double
    var seed: UInt64

    var totalElements: Int { stages.reduce(0) { $0 + $1.solution.totalElements } }
}

// MARK: - Engine

enum PuzzleEngine {

    static func generate(mode: GameModeType,
                         difficulty: Int,
                         size: BoardSize,
                         layout: BoardLayout,
                         seed: UInt64) -> Puzzle {
        var rng = SeededRandom(seed: seed)
        let profile = DifficultyProfile(level: difficulty)
        let dim = size.dimension
        let cellCount = dim * dim
        let n = max(2, min(profile.objectCount, max(2, cellCount / 3)))
        let decoys = max(0, min(profile.decoyCount, cellCount - n - 1))

        let ctx = Context(profile: profile, size: size, dim: dim, cellCount: cellCount,
                          objectCount: n, decoyCount: decoys, layout: layout)

        let stages: [PuzzleStage]
        switch mode {
        case .objects:     stages = makeObjects(ctx, &rng)
        case .sequence:    stages = makeSequence(ctx, &rng)
        case .tactical:    stages = makeTactical(ctx, &rng)
        case .route:       stages = makeRoute(ctx, &rng)
        case .safe:        stages = makeSafe(ctx, &rng)
        case .danger:      stages = makeDanger(ctx, &rng)
        case .combo:       stages = makeCombo(ctx, &rng)
        case .mirror:      stages = makeMirror(ctx, &rng)
        case .rotation:    stages = makeRotation(ctx, &rng)
        case .swap:        stages = makeSwap(ctx, &rng)
        case .difference:  stages = makeDifference(ctx, &rng)
        case .shape:       stages = makeShape(ctx, &rng)
        case .colors:      stages = makePaintAttribute(ctx, &rng, attribute: .color)
        case .symbols:     stages = makePaintAttribute(ctx, &rng, attribute: .symbol)
        case .multiStage:  stages = makeMultiStage(ctx, &rng)
        case .size:        stages = makePaintAttribute(ctx, &rng, attribute: .size)
        case .direction:   stages = makePaintAttribute(ctx, &rng, attribute: .direction)
        case .height:      stages = makePaintAttribute(ctx, &rng, attribute: .level)
        case .dynamic:     stages = makeDynamic(ctx, &rng)
        case .fading:      stages = makeFading(ctx, &rng)
        }

        return Puzzle(mode: mode, difficulty: profile.level, size: size,
                      layoutID: layout.id, layoutName: layout.name,
                      stages: stages, timeLimit: profile.timeLimit, seed: seed)
    }

    // MARK: - Context

    struct Context {
        let profile: DifficultyProfile
        let size: BoardSize
        let dim: Int
        let cellCount: Int
        let objectCount: Int
        let decoyCount: Int
        let layout: BoardLayout
    }

    // MARK: - Shared helpers

    private static func pool(_ ctx: Context, need: Int, _ rng: inout SeededRandom) -> [Coord] {
        let want = min(need, ctx.cellCount)
        var cells = ctx.layout.anchors.filter { $0.row < ctx.dim && $0.column < ctx.dim }
        var present = Set(cells)
        var guardCount = 0
        while cells.count < want && guardCount < ctx.cellCount * 24 {
            guardCount += 1
            let c = Coord(rng.int(ctx.dim), rng.int(ctx.dim))
            if present.insert(c).inserted { cells.append(c) }
        }
        return rng.shuffled(cells)
    }

    /// Layout anchors first (shuffled), then every remaining cell (shuffled).
    private static func orderedCandidates(_ ctx: Context, _ rng: inout SeededRandom) -> [Coord] {
        let anchors = rng.shuffled(ctx.layout.anchors.filter { $0.row < ctx.dim && $0.column < ctx.dim })
        let anchorSet = Set(anchors)
        var rest: [Coord] = []
        for r in 0..<ctx.dim {
            for c in 0..<ctx.dim {
                let coord = Coord(r, c)
                if !anchorSet.contains(coord) { rest.append(coord) }
            }
        }
        return anchors + rng.shuffled(rest)
    }

    /// Greedily builds a cell set S with S and transform(S) fully disjoint, so a
    /// player answering with the untransformed positions scores exactly zero.
    private static func transformIndependentSet(_ ctx: Context,
                                                limit: Int,
                                                _ rng: inout SeededRandom,
                                                transform: (Coord) -> Coord) -> [Coord] {
        var chosen: [Coord] = []
        var chosenSet = Set<Coord>()
        var images = Set<Coord>()
        for c in orderedCandidates(ctx, &rng) {
            if chosen.count >= limit { break }
            let t = transform(c)
            if t == c { continue }
            if chosenSet.contains(t) { continue }
            if images.contains(c) { continue }
            chosen.append(c)
            chosenSet.insert(c)
            images.insert(t)
        }
        return chosen
    }

    private static func freeCells(_ ctx: Context, excluding used: Set<Coord>, count: Int,
                                  _ rng: inout SeededRandom) -> [Coord] {
        var all: [Coord] = []
        for r in 0..<ctx.dim {
            for c in 0..<ctx.dim {
                let coord = Coord(r, c)
                if !used.contains(coord) { all.append(coord) }
            }
        }
        return Array(rng.shuffled(all).prefix(max(0, count)))
    }

    private static func makeObject(theme: ObjectTheme,
                                   _ rng: inout SeededRandom,
                                   symbol: SymbolType? = nil,
                                   color: ColorType? = nil,
                                   direction: Direction? = nil,
                                   size: ObjectSize? = nil,
                                   level: HeightLevel? = nil) -> GameObject {
        let sym = symbol ?? rng.pick(theme.symbols)
        let col = color ?? rng.pick(theme.colors)
        let dir = direction ?? rng.pick(Direction.allCases)
        let sz = size ?? .medium
        let lvl = level ?? .low
        return GameObject(category: theme, symbol: sym, color: col,
                          direction: dir, size: sz, level: lvl)
    }

    private static func board(_ ctx: Context) -> GameBoard { GameBoard(size: ctx.size) }

    // MARK: - 1. objects

    private static func makeObjects(_ ctx: Context, _ rng: inout SeededRandom) -> [PuzzleStage] {
        let targetTheme = ctx.layout.theme
        let decoyTheme = ObjectTheme.allCases[(targetTheme.rawValue + 5) % ObjectTheme.allCases.count]
        let cells = pool(ctx, need: ctx.objectCount + ctx.decoyCount, &rng)
        let targets = Array(cells.prefix(ctx.objectCount))
        let decoyCells = Array(cells.dropFirst(ctx.objectCount).prefix(ctx.decoyCount))

        var b = board(ctx)
        for c in targets { b.place(makeObject(theme: targetTheme, &rng, size: .medium), at: c) }
        for c in decoyCells {
            b.place(makeObject(theme: decoyTheme, &rng, color: .slate, size: .small), at: c)
        }

        var solution = Solution(required: targets, orderMatters: false)
        solution.traps = Set(decoyCells)

        let previewPrompt = ctx.decoyCount > 0
            ? "Memorize only the \(targetTheme.title) objects. Grey markers are decoys."
            : "Memorize every object position."
        let stage = PuzzleStage(frames: [b],
                                frameInterval: ctx.profile.previewSeconds,
                                previewSeconds: ctx.profile.previewSeconds,
                                recallBoard: nil,
                                solution: solution,
                                interaction: .tapCells(expected: targets.count,
                                                       maxSelections: min(ctx.cellCount, targets.count + 2),
                                                       showExpected: true),
                                previewPrompt: previewPrompt,
                                recallPrompt: "Mark every \(targetTheme.title) position.")
        return [stage]
    }

    // MARK: - 2. sequence

    private static func makeSequence(_ ctx: Context, _ rng: inout SeededRandom) -> [PuzzleStage] {
        let k = max(3, min(ctx.objectCount, 7, ctx.cellCount))
        let cells = Array(pool(ctx, need: k, &rng).prefix(k))
        let theme = ctx.layout.theme

        var objects: [GameObject] = []
        for _ in cells { objects.append(makeObject(theme: theme, &rng)) }

        var frames: [GameBoard] = []
        var running = board(ctx)
        for (i, c) in cells.enumerated() {
            running.place(objects[i], at: c)
            frames.append(running)
        }
        let interval = max(0.55, ctx.profile.frameInterval)

        var solution = Solution(required: cells, orderMatters: true)
        solution.extraWeight = 1.0

        return [PuzzleStage(frames: frames,
                            frameInterval: interval,
                            previewSeconds: Double(frames.count) * interval,
                            recallBoard: nil,
                            solution: solution,
                            interaction: .tapOrdered(expected: k),
                            previewPrompt: "Watch the arrival order.",
                            recallPrompt: "Tap the cells in their arrival order.")]
    }

    // MARK: - 3. tactical

    private static func makeTactical(_ ctx: Context, _ rng: inout SeededRandom) -> [PuzzleStage] {
        let k = max(3, min(ctx.objectCount, 8, ctx.cellCount - 1))
        let classCount = min(3, ObjectTheme.allCases.count)
        let classes = rng.sample(ObjectTheme.allCases, classCount)
        let cells = pool(ctx, need: k + ctx.decoyCount, &rng)
        let targets = Array(cells.prefix(k))
        let decoyCells = Array(cells.dropFirst(k).prefix(ctx.decoyCount))

        var b = board(ctx)
        var paint: [Coord: Int] = [:]
        for (i, c) in targets.enumerated() {
            let cls = classes[i % classes.count]
            b.place(makeObject(theme: cls, &rng,
                               symbol: cls.symbols[0], color: cls.colors[0]), at: c)
            paint[c] = cls.rawValue
        }
        let neutral = ObjectTheme.allCases.first { !classes.contains($0) } ?? .geometric
        for c in decoyCells {
            b.place(makeObject(theme: neutral, &rng, symbol: .bars, color: .slate, size: .small), at: c)
        }

        var solution = Solution(required: targets, orderMatters: false)
        solution.paint = paint
        solution.traps = Set(decoyCells)

        let names = classes.map { $0.title }.joined(separator: ", ")
        return [PuzzleStage(frames: [b],
                            frameInterval: ctx.profile.previewSeconds,
                            previewSeconds: ctx.profile.previewSeconds,
                            recallBoard: nil,
                            solution: solution,
                            interaction: .paint(attribute: .category,
                                                options: classes.map { $0.rawValue },
                                                expected: k,
                                                maxSelections: min(ctx.cellCount, k + 2)),
                            previewPrompt: "Unit classes: \(names). Grey bars are neutral.",
                            recallPrompt: "Place each unit and label its class.")]
    }

    // MARK: - 4. route

    private static func makeRoute(_ ctx: Context, _ rng: inout SeededRandom) -> [PuzzleStage] {
        let target = max(4, min(ctx.objectCount + 1, ctx.dim * 2 - 1, ctx.cellCount))
        let path = randomPath(dim: ctx.dim, length: target, &rng)
        let theme = ctx.layout.theme

        var frames: [GameBoard] = []
        var running = board(ctx)
        for c in path {
            running.place(makeObject(theme: theme, &rng, symbol: .square, color: theme.colors[0]), at: c)
            frames.append(running)
        }
        let interval = max(0.5, ctx.profile.frameInterval)

        var solution = Solution(required: path, orderMatters: true)
        solution.extraWeight = 1.0

        return [PuzzleStage(frames: frames,
                            frameInterval: interval,
                            previewSeconds: Double(frames.count) * interval,
                            recallBoard: nil,
                            solution: solution,
                            interaction: .tapPath(expected: path.count),
                            previewPrompt: "Follow the route as it is drawn.",
                            recallPrompt: "Retrace the route. Each step must touch the previous cell.")]
    }

    private static func randomPath(dim: Int, length: Int, _ rng: inout SeededRandom) -> [Coord] {
        let wanted = min(length, dim * dim)
        for _ in 0..<40 {
            var path: [Coord] = [Coord(rng.int(dim), rng.int(dim))]
            var visited: Set<Coord> = Set(path)
            while path.count < wanted {
                let cur = path[path.count - 1]
                let candidates = rng.shuffled(Direction.allCases).compactMap { d -> Coord? in
                    let next = Coord(cur.row + d.delta.0, cur.column + d.delta.1)
                    guard next.row >= 0, next.row < dim, next.column >= 0, next.column < dim,
                          !visited.contains(next) else { return nil }
                    return next
                }
                guard let next = candidates.first else { break }
                path.append(next)
                visited.insert(next)
            }
            if path.count == wanted { return path }
        }
        // Deterministic fallback: snake along the first row(s).
        var fallback: [Coord] = []
        var r = 0, c = 0, dir = 1
        while fallback.count < wanted {
            fallback.append(Coord(r, c))
            if (dir == 1 && c == dim - 1) || (dir == -1 && c == 0) {
                r += 1; dir *= -1
                if r >= dim { break }
            } else {
                c += dir
            }
        }
        return fallback
    }

    // MARK: - 5. safe

    private static func makeSafe(_ ctx: Context, _ rng: inout SeededRandom) -> [PuzzleStage] {
        let k = max(3, min(ctx.objectCount, max(3, ctx.cellCount / 3)))
        let safeCells = Array(pool(ctx, need: k, &rng).prefix(k))
        var b = board(ctx)
        for c in safeCells {
            b.place(makeObject(theme: .botanical, &rng, symbol: .hexagon, color: .green, size: .large), at: c)
        }
        var solution = Solution(required: safeCells, orderMatters: false)
        solution.extraWeight = 1.0

        return [PuzzleStage(frames: [b],
                            frameInterval: ctx.profile.previewSeconds,
                            previewSeconds: ctx.profile.previewSeconds,
                            recallBoard: nil,
                            solution: solution,
                            interaction: .tapCells(expected: k,
                                                   maxSelections: min(ctx.cellCount, k * 2),
                                                   showExpected: false),
                            previewPrompt: "Green ground is safe. The count stays hidden.",
                            recallPrompt: "Step only on safe ground. Every wrong cell costs a point.")]
    }

    // MARK: - 6. danger

    private static func makeDanger(_ ctx: Context, _ rng: inout SeededRandom) -> [PuzzleStage] {
        let trapCount = max(2, min(ctx.decoyCount + 2, max(2, ctx.cellCount / 4)))
        let goalCount = max(2, min(ctx.objectCount, max(2, ctx.cellCount - trapCount - 1)))
        let cells = pool(ctx, need: goalCount + trapCount, &rng)
        let goals = Array(cells.prefix(goalCount))
        var traps = Array(cells.dropFirst(goalCount).prefix(trapCount))
        if traps.count < trapCount {
            traps += freeCells(ctx, excluding: Set(goals + traps), count: trapCount - traps.count, &rng)
        }

        var b = board(ctx)
        for c in goals {
            b.place(makeObject(theme: .celestial, &rng, symbol: .star, color: .green, size: .medium), at: c)
        }
        for c in traps {
            b.place(makeObject(theme: .thermal, &rng, symbol: .cross, color: .red, size: .large), at: c)
        }

        var solution = Solution(required: goals, orderMatters: false)
        solution.traps = Set(traps)
        solution.extraWeight = 1.0
        solution.trapWeight = 2.0

        return [PuzzleStage(frames: [b],
                            frameInterval: ctx.profile.previewSeconds,
                            previewSeconds: ctx.profile.previewSeconds,
                            recallBoard: nil,
                            solution: solution,
                            interaction: .tapCells(expected: goalCount,
                                                   maxSelections: min(ctx.cellCount, goalCount + 3),
                                                   showExpected: true),
                            previewPrompt: "Green stars are targets. Red crosses are traps.",
                            recallPrompt: "Collect the targets. A trap costs double.")]
    }

    // MARK: - 7. combo

    private static func makeCombo(_ ctx: Context, _ rng: inout SeededRandom) -> [PuzzleStage] {
        let k = max(3, min(ctx.objectCount, 6, ctx.cellCount))
        let cells = Array(pool(ctx, need: k, &rng).prefix(k))
        let palette = Array(rng.shuffled(ColorType.allCases).prefix(max(2, min(ctx.profile.paletteWidth, 4))))

        var colorsUsed: [ColorType] = []
        for i in 0..<cells.count { colorsUsed.append(palette[i % palette.count]) }
        colorsUsed = rng.shuffled(colorsUsed)

        var frames: [GameBoard] = []
        var running = board(ctx)
        for (i, c) in cells.enumerated() {
            running.place(makeObject(theme: .geometric, &rng, symbol: .circle,
                                     color: colorsUsed[i], size: .medium), at: c)
            frames.append(running)
        }
        let interval = max(0.6, ctx.profile.frameInterval)
        let previewTotal = Double(frames.count) * interval

        var s1 = Solution(required: cells, orderMatters: false)
        s1.extraWeight = 1.0

        var paint: [Coord: Int] = [:]
        for (i, c) in cells.enumerated() { paint[c] = colorsUsed[i].rawValue }
        var s2 = Solution(required: cells, orderMatters: false)
        s2.paint = paint

        var s3 = Solution(required: cells, orderMatters: true)
        s3.extraWeight = 1.0

        let stage1 = PuzzleStage(frames: frames, frameInterval: interval, previewSeconds: previewTotal,
                                 recallBoard: nil, solution: s1,
                                 interaction: .tapCells(expected: k, maxSelections: min(ctx.cellCount, k + 2), showExpected: true),
                                 previewPrompt: "One preview, three checks: positions, colours, order.",
                                 recallPrompt: "Check 1 of 3 — mark every position.")
        let stage2 = PuzzleStage(frames: frames, frameInterval: interval, previewSeconds: previewTotal,
                                 recallBoard: nil, solution: s2,
                                 interaction: .paint(attribute: .color, options: palette.map { $0.rawValue },
                                                     expected: k, maxSelections: min(ctx.cellCount, k + 2)),
                                 previewPrompt: "", recallPrompt: "Check 2 of 3 — colour each position.",
                                 sharedPreview: true)
        let stage3 = PuzzleStage(frames: frames, frameInterval: interval, previewSeconds: previewTotal,
                                 recallBoard: nil, solution: s3,
                                 interaction: .tapOrdered(expected: k),
                                 previewPrompt: "", recallPrompt: "Check 3 of 3 — reproduce the arrival order.",
                                 sharedPreview: true)
        return [stage1, stage2, stage3]
    }

    // MARK: - 8. mirror

    private static func makeMirror(_ ctx: Context, _ rng: inout SeededRandom) -> [PuzzleStage] {
        let horizontal = rng.bool()
        let k = max(2, min(ctx.objectCount, ctx.cellCount - 1))
        let dim = ctx.dim
        var cells = transformIndependentSet(ctx, limit: k, &rng) {
            mirror($0, dim: dim, horizontal: horizontal)
        }
        if cells.count < 2 {
            // Only possible on a 1-wide board; fall back to any asymmetric pair.
            cells = Array(pool(ctx, need: max(2, k), &rng).prefix(max(2, k)))
        }

        var b = board(ctx)
        for c in cells {
            b.place(makeObject(theme: ctx.layout.theme, &rng, symbol: .diamond), at: c)
        }
        let answer = cells.map { mirror($0, dim: ctx.dim, horizontal: horizontal) }
        var solution = Solution(required: answer, orderMatters: false)
        solution.extraWeight = 1.0

        let axis = horizontal ? "left-right" : "top-bottom"
        return [PuzzleStage(frames: [b],
                            frameInterval: ctx.profile.previewSeconds,
                            previewSeconds: ctx.profile.previewSeconds,
                            recallBoard: nil,
                            solution: solution,
                            interaction: .tapCells(expected: answer.count,
                                                   maxSelections: min(ctx.cellCount, answer.count + 2),
                                                   showExpected: true),
                            previewPrompt: "The board will be reflected \(axis) before the check.",
                            recallPrompt: "Mark the \(axis) mirrored positions.")]
    }

    static func mirror(_ c: Coord, dim: Int, horizontal: Bool) -> Coord {
        horizontal ? Coord(c.row, dim - 1 - c.column) : Coord(dim - 1 - c.row, c.column)
    }

    // MARK: - 9. rotation

    private static func makeRotation(_ ctx: Context, _ rng: inout SeededRandom) -> [PuzzleStage] {
        let quarters = 1 + rng.int(3)
        let k = max(2, min(ctx.objectCount, ctx.cellCount - 1))
        let dim = ctx.dim
        var cells = transformIndependentSet(ctx, limit: k, &rng) {
            rotate($0, dim: dim, quarters: quarters)
        }
        if cells.count < 2 {
            cells = Array(pool(ctx, need: max(2, k), &rng).prefix(max(2, k)))
        }

        var b = board(ctx)
        for c in cells {
            b.place(makeObject(theme: ctx.layout.theme, &rng, symbol: .hexagon), at: c)
        }
        let answer = cells.map { rotate($0, dim: ctx.dim, quarters: quarters) }
        var solution = Solution(required: answer, orderMatters: false)
        solution.extraWeight = 1.0

        let degrees = quarters * 90
        return [PuzzleStage(frames: [b],
                            frameInterval: ctx.profile.previewSeconds,
                            previewSeconds: ctx.profile.previewSeconds,
                            recallBoard: nil,
                            solution: solution,
                            interaction: .tapCells(expected: answer.count,
                                                   maxSelections: min(ctx.cellCount, answer.count + 2),
                                                   showExpected: true),
                            previewPrompt: "The board will rotate \(degrees) degrees clockwise before the check.",
                            recallPrompt: "Mark the positions after a \(degrees) degree clockwise turn.")]
    }

    static func rotate(_ c: Coord, dim: Int, quarters: Int) -> Coord {
        var out = c
        for _ in 0..<((quarters % 4 + 4) % 4) {
            out = Coord(out.column, dim - 1 - out.row)
        }
        return out
    }

    // MARK: - 10. swap

    private static func makeSwap(_ ctx: Context, _ rng: inout SeededRandom) -> [PuzzleStage] {
        let k = max(3, min(ctx.objectCount, max(3, ctx.cellCount / 3)))
        let cells = Array(pool(ctx, need: k, &rng).prefix(k))
        let theme = ctx.layout.theme

        var a = board(ctx)
        var objects: [GameObject] = []
        for c in cells {
            let o = makeObject(theme: theme, &rng, symbol: .square)
            objects.append(o)
            a.place(o, at: c)
        }

        let moveCount = max(1, min(ctx.profile.movingCount, k - 1))
        let movingIdx = Array(rng.shuffled(Array(0..<k)).prefix(moveCount))
        var destinations = freeCells(ctx, excluding: Set(cells), count: moveCount, &rng)
        if destinations.count < moveCount { destinations += Array(repeating: cells[0], count: moveCount - destinations.count) }

        var b = a
        var changed = Set<Coord>()
        for (i, idx) in movingIdx.enumerated() {
            let from = cells[idx]
            let to = destinations[i]
            guard from != to else { continue }
            b.place(nil, at: from)
            b.place(objects[idx], at: to)
            changed.insert(from)
            changed.insert(to)
        }
        if changed.isEmpty {
            // Guaranteed change fallback.
            let from = cells[0]
            let to = freeCells(ctx, excluding: Set(cells), count: 1, &rng).first ?? from
            if to != from {
                b.place(nil, at: from)
                b.place(objects[0], at: to)
                changed.insert(from); changed.insert(to)
            }
        }

        var solution = Solution(required: Array(changed).sorted { $0.row == $1.row ? $0.column < $1.column : $0.row < $1.row },
                                orderMatters: false)
        solution.extraWeight = 1.0

        let interval = max(1.2, ctx.profile.previewSeconds / 2.0)
        return [PuzzleStage(frames: [a, b],
                            frameInterval: interval,
                            previewSeconds: interval * 2,
                            recallBoard: nil,
                            solution: solution,
                            interaction: .tapCells(expected: solution.required.count,
                                                   maxSelections: min(ctx.cellCount, solution.required.count + 3),
                                                   showExpected: true),
                            previewPrompt: "Two frames. Watch what moves.",
                            recallPrompt: "Mark every cell that changed between the frames.")]
    }

    // MARK: - 11. difference

    private static func makeDifference(_ ctx: Context, _ rng: inout SeededRandom) -> [PuzzleStage] {
        let k = max(4, min(ctx.objectCount + 2, max(4, ctx.cellCount / 3)))
        let cells = Array(pool(ctx, need: k, &rng).prefix(k))
        let theme = ctx.layout.theme

        var a = board(ctx)
        for c in cells { a.place(makeObject(theme: theme, &rng), at: c) }

        let diffCount = max(2, min(ctx.decoyCount + 2, max(2, cells.count / 2)))
        let targets = Array(rng.shuffled(cells).prefix(diffCount))
        var b = a
        var changed: [Coord] = []
        for c in targets {
            guard let existing = b.object(at: c) else { continue }
            switch rng.int(3) {
            case 0:
                b.place(nil, at: c)
            case 1:
                var o = existing
                let others = theme.colors.filter { $0 != existing.color }
                o.color = others.isEmpty ? existing.color : rng.pick(others)
                if o.color == existing.color {
                    o.color = ColorType.allCases.first { $0 != existing.color } ?? existing.color
                }
                b.place(o, at: c)
            default:
                var o = existing
                let others = theme.symbols.filter { $0 != existing.symbol }
                o.symbol = others.isEmpty ? existing.symbol : rng.pick(others)
                if o.symbol == existing.symbol {
                    o.symbol = SymbolType.allCases.first { $0 != existing.symbol } ?? existing.symbol
                }
                b.place(o, at: c)
            }
            changed.append(c)
        }

        var solution = Solution(required: changed, orderMatters: false)
        solution.extraWeight = 1.0

        return [PuzzleStage(frames: [a],
                            frameInterval: ctx.profile.previewSeconds,
                            previewSeconds: ctx.profile.previewSeconds,
                            recallBoard: b,
                            solution: solution,
                            interaction: .tapCells(expected: changed.count,
                                                   maxSelections: min(ctx.cellCount, changed.count + 3),
                                                   showExpected: true),
                            previewPrompt: "Study the board. It comes back altered.",
                            recallPrompt: "Mark every cell that differs from the original.")]
    }

    // MARK: - 12. shape

    private static func makeShape(_ ctx: Context, _ rng: inout SeededRandom) -> [PuzzleStage] {
        let limit = max(5, ctx.cellCount / 2)
        var full: [Coord] = []
        var vertices: [Coord] = []
        var label = "line"

        // The structure must always cover at least two cells beyond its vertices,
        // otherwise "just tap the markers you saw" would be a full answer.
        for _ in 0..<40 {
            let (f, v, name) = candidateShape(dim: ctx.dim, &rng)
            if f.count >= v.count + 2 && f.count <= limit && v.count >= 2 {
                full = f; vertices = v; label = name; break
            }
        }
        if full.isEmpty {
            let len = min(4, ctx.dim * ctx.dim)
            var built: [Coord] = []
            var r = 0, c = 0
            while built.count < len {
                built.append(Coord(r, c))
                c += 1
                if c >= ctx.dim { c = 0; r += 1 }
                if r >= ctx.dim { break }
            }
            full = built
            vertices = [built[0], built[built.count - 1]]
            label = "line"
        }

        var b = board(ctx)
        for c in vertices {
            b.place(makeObject(theme: .mineral, &rng, symbol: .diamond, color: .amber, size: .medium), at: c)
        }

        var solution = Solution(required: full, orderMatters: false)
        solution.extraWeight = 1.0

        return [PuzzleStage(frames: [b],
                            frameInterval: ctx.profile.previewSeconds,
                            previewSeconds: ctx.profile.previewSeconds,
                            recallBoard: nil,
                            solution: solution,
                            interaction: .tapCells(expected: full.count,
                                                   maxSelections: min(ctx.cellCount, full.count + 3),
                                                   showExpected: true),
                            previewPrompt: "Only the vertices of a \(label) are shown.",
                            recallPrompt: "Rebuild the whole \(label) — every cell it covers.")]
    }

    private static func candidateShape(dim: Int, _ rng: inout SeededRandom) -> ([Coord], [Coord], String) {
        switch rng.int(3) {
        case 0 where dim >= 4:
            let h = 2 + rng.int(max(1, dim - 3))
            let w = 2 + rng.int(max(1, dim - 3))
            let r0 = rng.int(max(1, dim - h))
            let c0 = rng.int(max(1, dim - w))
            let r1 = r0 + h, c1 = c0 + w
            guard r1 < dim, c1 < dim else { return ([], [], "rectangle") }
            var cells: [Coord] = []
            for c in c0...c1 { cells.append(Coord(r0, c)); cells.append(Coord(r1, c)) }
            for r in (r0 + 1)...(r1 - 1) { cells.append(Coord(r, c0)); cells.append(Coord(r, c1)) }
            let verts = [Coord(r0, c0), Coord(r0, c1), Coord(r1, c0), Coord(r1, c1)]
            return (dedupe(cells), verts, "rectangle")
        case 1:
            let vertical = rng.bool()
            let len = 3 + rng.int(max(1, dim - 2))
            guard len <= dim else { return ([], [], "line") }
            let fixed = rng.int(dim)
            let start = rng.int(max(1, dim - len + 1))
            var cells: [Coord] = []
            for i in 0..<len {
                cells.append(vertical ? Coord(start + i, fixed) : Coord(fixed, start + i))
            }
            return (cells, [cells[0], cells[cells.count - 1]], "line")
        default:
            let armA = 2 + rng.int(max(1, dim - 2))
            let armB = 2 + rng.int(max(1, dim - 2))
            let r0 = rng.int(max(1, dim - armA))
            let c0 = rng.int(max(1, dim - armB))
            guard r0 + armA < dim, c0 + armB < dim else { return ([], [], "corner") }
            var cells: [Coord] = []
            for i in 0...armA { cells.append(Coord(r0 + i, c0)) }
            for j in 1...armB { cells.append(Coord(r0 + armA, c0 + j)) }
            let verts = [Coord(r0, c0), Coord(r0 + armA, c0), Coord(r0 + armA, c0 + armB)]
            return (dedupe(cells), verts, "corner")
        }
    }

    private static func dedupe(_ cells: [Coord]) -> [Coord] {
        var seen = Set<Coord>()
        var out: [Coord] = []
        for c in cells where seen.insert(c).inserted { out.append(c) }
        return out
    }

    // MARK: - 13/14/16/17/18. paint attribute modes

    private static func makePaintAttribute(_ ctx: Context,
                                           _ rng: inout SeededRandom,
                                           attribute: PaintAttribute) -> [PuzzleStage] {
        let k = max(3, min(ctx.objectCount, 8, ctx.cellCount))
        let cells = Array(pool(ctx, need: k, &rng).prefix(k))
        let theme = ctx.layout.theme

        var options: [Int]
        switch attribute {
        case .color:
            options = Array(rng.shuffled(ColorType.allCases)
                .prefix(max(2, min(ctx.profile.paletteWidth, 6)))).map { $0.rawValue }.sorted()
        case .symbol:
            options = Array(rng.shuffled(SymbolType.allCases)
                .prefix(max(2, min(ctx.profile.paletteWidth, 6)))).map { $0.rawValue }.sorted()
        case .size:
            options = ObjectSize.allCases.map { $0.rawValue }
        case .direction:
            options = Direction.allCases.map { $0.rawValue }
        case .level:
            options = HeightLevel.allCases.map { $0.rawValue }
        case .category:
            options = Array(rng.shuffled(ObjectTheme.allCases).prefix(3)).map { $0.rawValue }.sorted()
        }

        // Guarantee at least two distinct values are actually used.
        var values: [Int] = []
        for i in 0..<cells.count { values.append(options[i % options.count]) }
        values = rng.shuffled(values)
        if Set(values).count < 2 && options.count >= 2 {
            values[0] = options[0]
            values[values.count - 1] = options[1]
        }

        let fixedColor: ColorType = theme.colors[0]
        let fixedSymbol: SymbolType = theme.symbols[0]

        var b = board(ctx)
        var paint: [Coord: Int] = [:]
        for (i, c) in cells.enumerated() {
            let v = values[i]
            paint[c] = v
            let o: GameObject
            switch attribute {
            case .color:
                o = makeObject(theme: theme, &rng, symbol: fixedSymbol,
                               color: ColorType(rawValue: v) ?? .blue, size: .medium)
            case .symbol:
                o = makeObject(theme: theme, &rng, symbol: SymbolType(rawValue: v) ?? .circle,
                               color: fixedColor, size: .medium)
            case .size:
                o = makeObject(theme: theme, &rng, symbol: fixedSymbol, color: fixedColor,
                               size: ObjectSize(rawValue: v) ?? .medium)
            case .direction:
                o = makeObject(theme: theme, &rng, symbol: .chevron, color: fixedColor,
                               direction: Direction(rawValue: v) ?? .up, size: .large)
            case .level:
                o = makeObject(theme: theme, &rng, symbol: .ring, color: fixedColor,
                               size: .large, level: HeightLevel(rawValue: v) ?? .low)
            case .category:
                let t = ObjectTheme(rawValue: v) ?? theme
                o = makeObject(theme: t, &rng, symbol: t.symbols[0], color: t.colors[0])
            }
            b.place(o, at: c)
        }

        var solution = Solution(required: cells, orderMatters: false)
        solution.paint = paint
        solution.extraWeight = 1.0

        let previewText: String
        let recallText: String
        switch attribute {
        case .color:
            previewText = "Same symbol everywhere — only the colour varies."
            recallText = "Colour every remembered position."
        case .symbol:
            previewText = "Same colour everywhere — only the symbol varies."
            recallText = "Give every remembered position its symbol."
        case .size:
            previewText = "Only the scale varies."
            recallText = "Set the size class of every remembered position."
        case .direction:
            previewText = "Every marker points somewhere."
            recallText = "Set the direction of every remembered position."
        case .level:
            previewText = "Ring count shows the layer level."
            recallText = "Set the layer level of every remembered position."
        case .category:
            previewText = "Classes vary."
            recallText = "Label the class of every remembered position."
        }

        return [PuzzleStage(frames: [b],
                            frameInterval: ctx.profile.previewSeconds,
                            previewSeconds: ctx.profile.previewSeconds,
                            recallBoard: nil,
                            solution: solution,
                            interaction: .paint(attribute: attribute, options: options,
                                                expected: k,
                                                maxSelections: min(ctx.cellCount, k + 2)),
                            previewPrompt: previewText,
                            recallPrompt: recallText)]
    }

    // MARK: - 15. multiStage

    private static func makeMultiStage(_ ctx: Context, _ rng: inout SeededRandom) -> [PuzzleStage] {
        let stageCount = max(2, ctx.profile.stageCount)
        var stages: [PuzzleStage] = []
        let perStage = max(2, min(ctx.objectCount / 2 + 1, 5))

        for s in 0..<stageCount {
            let layout = LayoutCatalog.layout(id: ctx.layout.id + s * 17 + 3)
            let stageCtx = Context(profile: ctx.profile, size: ctx.size, dim: ctx.dim,
                                   cellCount: ctx.cellCount, objectCount: perStage,
                                   decoyCount: 0, layout: layout)
            let cells = Array(pool(stageCtx, need: perStage, &rng).prefix(perStage))
            let theme = layout.theme
            let kind = s % 3

            if kind == 1 {
                // Ordered sub-task.
                var frames: [GameBoard] = []
                var running = board(stageCtx)
                for c in cells {
                    running.place(makeObject(theme: theme, &rng, symbol: .triangle), at: c)
                    frames.append(running)
                }
                let interval = max(0.55, ctx.profile.frameInterval)
                var solution = Solution(required: cells, orderMatters: true)
                solution.extraWeight = 1.0
                stages.append(PuzzleStage(frames: frames, frameInterval: interval,
                                          previewSeconds: Double(frames.count) * interval,
                                          recallBoard: nil, solution: solution,
                                          interaction: .tapOrdered(expected: cells.count),
                                          previewPrompt: "Stage \(s + 1) of \(stageCount) — order matters.",
                                          recallPrompt: "Stage \(s + 1) — reproduce the order."))
            } else if kind == 2 {
                // Colour sub-task.
                let palette = Array(rng.shuffled(ColorType.allCases).prefix(3))
                var b = board(stageCtx)
                var paint: [Coord: Int] = [:]
                for (i, c) in cells.enumerated() {
                    let col = palette[i % palette.count]
                    paint[c] = col.rawValue
                    b.place(makeObject(theme: theme, &rng, symbol: .circle, color: col), at: c)
                }
                var solution = Solution(required: cells, orderMatters: false)
                solution.paint = paint
                stages.append(PuzzleStage(frames: [b], frameInterval: ctx.profile.previewSeconds,
                                          previewSeconds: max(3.0, ctx.profile.previewSeconds * 0.7),
                                          recallBoard: nil, solution: solution,
                                          interaction: .paint(attribute: .color,
                                                              options: palette.map { $0.rawValue }.sorted(),
                                                              expected: cells.count,
                                                              maxSelections: min(ctx.cellCount, cells.count + 2)),
                                          previewPrompt: "Stage \(s + 1) of \(stageCount) — colours matter.",
                                          recallPrompt: "Stage \(s + 1) — colour each position."))
            } else {
                var b = board(stageCtx)
                for c in cells { b.place(makeObject(theme: theme, &rng, symbol: .square), at: c) }
                var solution = Solution(required: cells, orderMatters: false)
                solution.extraWeight = 1.0
                stages.append(PuzzleStage(frames: [b], frameInterval: ctx.profile.previewSeconds,
                                          previewSeconds: max(3.0, ctx.profile.previewSeconds * 0.7),
                                          recallBoard: nil, solution: solution,
                                          interaction: .tapCells(expected: cells.count,
                                                                 maxSelections: min(ctx.cellCount, cells.count + 2),
                                                                 showExpected: true),
                                          previewPrompt: "Stage \(s + 1) of \(stageCount) — positions.",
                                          recallPrompt: "Stage \(s + 1) — mark every position."))
            }
        }
        return stages
    }

    // MARK: - 19. dynamic

    private static func makeDynamic(_ ctx: Context, _ rng: inout SeededRandom) -> [PuzzleStage] {
        let k = max(3, min(ctx.objectCount, max(3, ctx.cellCount / 3)))
        let cells = Array(pool(ctx, need: k, &rng).prefix(k))
        let theme = ctx.layout.theme

        var positions = cells
        var objects: [GameObject] = []
        for _ in cells { objects.append(makeObject(theme: theme, &rng, symbol: .circle)) }

        // At least half the objects move, so answering the initial layout can never
        // pass on its own.
        let moverTarget = max(ctx.profile.movingCount, (k + 1) / 2)
        let movers = Array(rng.shuffled(Array(0..<k)).prefix(max(1, min(moverTarget, k))))
        var moverDir: [Int: Direction] = [:]
        for m in movers { moverDir[m] = rng.pick(Direction.allCases) }

        var frames: [GameBoard] = []
        func snapshot(_ ps: [Coord]) -> GameBoard {
            var b = board(ctx)
            for (i, c) in ps.enumerated() { b.place(objects[i], at: c) }
            return b
        }
        frames.append(snapshot(positions))

        let steps = max(2, ctx.profile.frameCount)
        for _ in 0..<steps {
            var next = positions
            for m in movers {
                var dir = moverDir[m] ?? .right
                var target = Coord(next[m].row + dir.delta.0, next[m].column + dir.delta.1)
                var tries = 0
                while (target.row < 0 || target.row >= ctx.dim || target.column < 0 || target.column >= ctx.dim
                       || next.contains(target)) && tries < 4 {
                    dir = Direction.allCases[(dir.rawValue + 1) % 4]
                    target = Coord(next[m].row + dir.delta.0, next[m].column + dir.delta.1)
                    tries += 1
                }
                if target.row >= 0, target.row < ctx.dim, target.column >= 0, target.column < ctx.dim,
                   !next.contains(target) {
                    next[m] = target
                    moverDir[m] = dir
                }
            }
            positions = next
            frames.append(snapshot(positions))
        }

        // Any mover that drifted back onto its own starting cell gets nudged, so the
        // "answer the initial layout" strategy stays well below a pass.
        var nudged = false
        for m in movers where positions[m] == cells[m] {
            let taken = Set(positions)
            if let free = freeCells(ctx, excluding: taken, count: 1, &rng).first {
                positions[m] = free
                nudged = true
            }
        }
        if nudged || Set(positions) == Set(cells) {
            if Set(positions) == Set(cells),
               let free = freeCells(ctx, excluding: Set(positions), count: 1, &rng).first {
                positions[0] = free
            }
            frames.append(snapshot(positions))
        }

        var solution = Solution(required: positions, orderMatters: false)
        solution.extraWeight = 1.0
        let interval = max(0.55, ctx.profile.frameInterval)

        return [PuzzleStage(frames: frames, frameInterval: interval,
                            previewSeconds: Double(frames.count) * interval,
                            recallBoard: nil, solution: solution,
                            interaction: .tapCells(expected: positions.count,
                                                   maxSelections: min(ctx.cellCount, positions.count + 2),
                                                   showExpected: true),
                            previewPrompt: "Objects drift. Only where they stop counts.",
                            recallPrompt: "Mark the final positions.")]
    }

    // MARK: - 20. fading

    private static func makeFading(_ ctx: Context, _ rng: inout SeededRandom) -> [PuzzleStage] {
        let k = max(3, min(ctx.objectCount, max(3, ctx.cellCount / 3)))
        let cells = Array(pool(ctx, need: k, &rng).prefix(k))
        let theme = ctx.layout.theme

        var start = board(ctx)
        for c in cells { start.place(makeObject(theme: theme, &rng, symbol: .ring), at: c) }

        let keepVisible = max(1, k / 3)
        let fadeOrder = rng.shuffled(cells).prefix(k - keepVisible)

        var frames: [GameBoard] = [start]
        var running = start
        for c in fadeOrder {
            running.place(nil, at: c)
            frames.append(running)
        }

        var solution = Solution(required: cells, orderMatters: false)
        solution.extraWeight = 1.0
        let interval = max(0.5, ctx.profile.previewSeconds / Double(max(1, frames.count)))

        return [PuzzleStage(frames: frames, frameInterval: interval,
                            previewSeconds: Double(frames.count) * interval,
                            recallBoard: nil, solution: solution,
                            interaction: .tapCells(expected: cells.count,
                                                   maxSelections: min(ctx.cellCount, cells.count + 2),
                                                   showExpected: true),
                            previewPrompt: "Objects fade out one by one. The vanished ones still count.",
                            recallPrompt: "Mark every position, including the faded ones.")]
    }
}
