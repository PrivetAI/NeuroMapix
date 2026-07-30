import Foundation

// MARK: - Coordinates

struct Coord: Hashable, Codable, CustomStringConvertible {
    let row: Int
    let column: Int
    init(_ row: Int, _ column: Int) { self.row = row; self.column = column }
    var description: String { "\(row).\(column)" }
}

// MARK: - Board size

enum BoardSize: Int, Codable, CaseIterable, Identifiable {
    case x3 = 3, x4 = 4, x5 = 5, x6 = 6, x7 = 7, x8 = 8, x10 = 10

    var id: Int { rawValue }
    var dimension: Int { rawValue }
    var cellCount: Int { rawValue * rawValue }
    var label: String { "\(rawValue)x\(rawValue)" }

    var tierIndex: Int { BoardSize.allCases.firstIndex(of: self) ?? 0 }

    /// Boards unlock progressively as the player finishes sessions.
    var unlockGames: Int { [0, 3, 8, 15, 25, 40, 60][tierIndex] }

    static func forDifficulty(_ difficulty: Int) -> BoardSize {
        let all = BoardSize.allCases
        let index = min(max(difficulty, 1), all.count) - 1
        return all[index]
    }
}

// MARK: - Object attributes

enum ObjectTheme: Int, Codable, CaseIterable, Identifiable {
    case geometric = 0, celestial, mineral, botanical, nautical, circuit, glyphic, thermal, kinetic, spectral

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .geometric: return "Geometric"
        case .celestial: return "Celestial"
        case .mineral:   return "Mineral"
        case .botanical: return "Botanical"
        case .nautical:  return "Nautical"
        case .circuit:   return "Circuit"
        case .glyphic:   return "Glyphic"
        case .thermal:   return "Thermal"
        case .kinetic:   return "Kinetic"
        case .spectral:  return "Spectral"
        }
    }
    var summary: String {
        switch self {
        case .geometric: return "Plain outlines. The cleanest set for pure position work."
        case .celestial: return "Rings and stars. Rewards wide-field scanning."
        case .mineral:   return "Faceted forms with heavy silhouettes."
        case .botanical:  return "Soft arcs and spirals, low contrast between neighbours."
        case .nautical:  return "Chevrons and bars, strongly directional."
        case .circuit:   return "Crosses and squares on a tight lattice."
        case .glyphic:   return "Dense marks that resist quick labelling."
        case .thermal:   return "Warm palette, size differences read first."
        case .kinetic:   return "Arrow-led shapes built for direction drills."
        case .spectral:  return "Cool palette, colour differences read first."
        }
    }
    /// Symbols this theme draws from.
    var symbols: [SymbolType] {
        switch self {
        case .geometric: return [.circle, .square, .triangle, .diamond]
        case .celestial: return [.ring, .star, .circle, .arc]
        case .mineral:   return [.diamond, .hexagon, .triangle, .square]
        case .botanical: return [.spiral, .arc, .circle, .ring]
        case .nautical:  return [.chevron, .bars, .triangle, .arc]
        case .circuit:   return [.cross, .square, .bars, .hexagon]
        case .glyphic:   return [.cross, .spiral, .star, .diamond]
        case .thermal:   return [.hexagon, .circle, .star, .bars]
        case .kinetic:   return [.chevron, .triangle, .arc, .cross]
        case .spectral:  return [.ring, .arc, .spiral, .hexagon]
        }
    }
    var colors: [ColorType] {
        switch self {
        case .geometric: return [.blue, .slate, .teal]
        case .celestial: return [.violet, .blue, .magenta]
        case .mineral:   return [.slate, .teal, .blue]
        case .botanical: return [.green, .teal, .amber]
        case .nautical:  return [.blue, .teal, .slate]
        case .circuit:   return [.green, .blue, .violet]
        case .glyphic:   return [.magenta, .violet, .slate]
        case .thermal:   return [.amber, .red, .magenta]
        case .kinetic:   return [.amber, .green, .blue]
        case .spectral:  return [.teal, .violet, .blue]
        }
    }
}

enum SymbolType: Int, Codable, CaseIterable, Identifiable {
    case circle = 0, ring, square, diamond, triangle, chevron, cross, star, hexagon, arc, bars, spiral
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .circle: return "Disc"
        case .ring: return "Ring"
        case .square: return "Square"
        case .diamond: return "Diamond"
        case .triangle: return "Triangle"
        case .chevron: return "Chevron"
        case .cross: return "Cross"
        case .star: return "Star"
        case .hexagon: return "Hexagon"
        case .arc: return "Arc"
        case .bars: return "Bars"
        case .spiral: return "Spiral"
        }
    }
}

enum ColorType: Int, Codable, CaseIterable, Identifiable {
    case blue = 0, green, amber, red, violet, teal, magenta, slate
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .blue: return "Blue"
        case .green: return "Green"
        case .amber: return "Amber"
        case .red: return "Red"
        case .violet: return "Violet"
        case .teal: return "Teal"
        case .magenta: return "Magenta"
        case .slate: return "Slate"
        }
    }
    /// 0xRRGGBB
    var hex: UInt32 {
        switch self {
        case .blue: return 0x3454D1
        case .green: return 0x38B66B
        case .amber: return 0xF9A825
        case .red: return 0xD32F2F
        case .violet: return 0x7A4BD1
        case .teal: return 0x1F9E9E
        case .magenta: return 0xC2418F
        case .slate: return 0x5A6472
        }
    }
}

enum Direction: Int, Codable, CaseIterable, Identifiable {
    case up = 0, right, down, left
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .up: return "Up"
        case .right: return "Right"
        case .down: return "Down"
        case .left: return "Left"
        }
    }
    var radians: Double {
        switch self {
        case .up: return 0
        case .right: return .pi / 2
        case .down: return .pi
        case .left: return -.pi / 2
        }
    }
    var delta: (Int, Int) {
        switch self {
        case .up: return (-1, 0)
        case .right: return (0, 1)
        case .down: return (1, 0)
        case .left: return (0, -1)
        }
    }
}

enum ObjectSize: Int, Codable, CaseIterable, Identifiable {
    case small = 0, medium, large
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
    var scale: Double {
        switch self {
        case .small: return 0.42
        case .medium: return 0.64
        case .large: return 0.86
        }
    }
}

enum HeightLevel: Int, Codable, CaseIterable, Identifiable {
    case low = 0, mid, high
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .low: return "Level 1"
        case .mid: return "Level 2"
        case .high: return "Level 3"
        }
    }
    var rings: Int { rawValue + 1 }
}

// MARK: - Objects and boards

struct GameObject: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var category: ObjectTheme
    var symbol: SymbolType
    var color: ColorType
    var direction: Direction
    var size: ObjectSize
    var level: HeightLevel

    /// Attribute lookup used by the paint-style modes.
    func attributeValue(_ attribute: PaintAttribute) -> Int {
        switch attribute {
        case .category: return category.rawValue
        case .color: return color.rawValue
        case .symbol: return symbol.rawValue
        case .size: return size.rawValue
        case .direction: return direction.rawValue
        case .level: return level.rawValue
        }
    }
}

struct BoardCell: Codable, Hashable {
    var row: Int
    var column: Int
    var object: GameObject?
    var coord: Coord { Coord(row, column) }
}

struct GameBoard: Codable, Hashable {
    var size: BoardSize
    var cells: [BoardCell]

    init(size: BoardSize) {
        self.size = size
        var built: [BoardCell] = []
        built.reserveCapacity(size.cellCount)
        for r in 0..<size.dimension {
            for c in 0..<size.dimension {
                built.append(BoardCell(row: r, column: c, object: nil))
            }
        }
        self.cells = built
    }

    private func index(_ coord: Coord) -> Int? {
        guard coord.row >= 0, coord.row < size.dimension,
              coord.column >= 0, coord.column < size.dimension else { return nil }
        return coord.row * size.dimension + coord.column
    }

    func object(at coord: Coord) -> GameObject? {
        guard let i = index(coord) else { return nil }
        return cells[i].object
    }

    mutating func place(_ object: GameObject?, at coord: Coord) {
        guard let i = index(coord) else { return }
        cells[i].object = object
    }

    var occupied: [Coord] { cells.compactMap { $0.object == nil ? nil : $0.coord } }
    var occupiedSet: Set<Coord> { Set(occupied) }

    /// Canonical text form used for layout-distinctness proofs.
    var canonicalKey: String {
        let parts = cells.compactMap { cell -> String? in
            guard let o = cell.object else { return nil }
            return "\(cell.row),\(cell.column):\(o.symbol.rawValue).\(o.color.rawValue).\(o.direction.rawValue).\(o.size.rawValue).\(o.level.rawValue)"
        }
        return "d\(size.dimension)|" + parts.sorted().joined(separator: "|")
    }
}

// MARK: - Modes

enum GameModeType: Int, Codable, CaseIterable, Identifiable {
    case objects = 0, sequence, tactical, route, safe, danger, combo, mirror, rotation, swap
    case difference, shape, colors, symbols, multiStage, size, direction, height, dynamic, fading

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .objects: return "Object Recall"
        case .sequence: return "Sequence"
        case .tactical: return "Tactical Map"
        case .route: return "Route Trace"
        case .safe: return "Safe Ground"
        case .danger: return "Danger Field"
        case .combo: return "Combo Drill"
        case .mirror: return "Mirror Shift"
        case .rotation: return "Rotation"
        case .swap: return "Swap Watch"
        case .difference: return "Difference"
        case .shape: return "Shape Build"
        case .colors: return "Colour Match"
        case .symbols: return "Symbol Match"
        case .multiStage: return "Multi Stage"
        case .size: return "Size Recall"
        case .direction: return "Direction"
        case .height: return "Layer Height"
        case .dynamic: return "Dynamic Field"
        case .fading: return "Fading Set"
        }
    }

    var short: String {
        switch self {
        case .objects: return "Objects"
        case .sequence: return "Sequence"
        case .tactical: return "Tactical"
        case .route: return "Route"
        case .safe: return "Safe"
        case .danger: return "Danger"
        case .combo: return "Combo"
        case .mirror: return "Mirror"
        case .rotation: return "Rotation"
        case .swap: return "Swap"
        case .difference: return "Difference"
        case .shape: return "Shape"
        case .colors: return "Colours"
        case .symbols: return "Symbols"
        case .multiStage: return "Stages"
        case .size: return "Size"
        case .direction: return "Direction"
        case .height: return "Height"
        case .dynamic: return "Dynamic"
        case .fading: return "Fading"
        }
    }

    var brief: String {
        switch self {
        case .objects: return "Memorize every object position, then mark all of them on the empty board."
        case .sequence: return "Objects arrive one at a time. Reproduce the exact arrival order."
        case .tactical: return "Each unit belongs to a class. Mark the position and label the class."
        case .route: return "A connected route lights up. Retrace it cell by cell without breaking contact."
        case .safe: return "Only some ground is safe. The count is hidden and every wrong cell costs you."
        case .danger: return "Traps and targets share the board. Collect targets, avoid traps at double cost."
        case .combo: return "One preview, three checks: positions, colours and order, all summed."
        case .mirror: return "The board is reflected before the check. Answer in mirrored coordinates."
        case .rotation: return "The board rotates before the check. Answer in rotated coordinates."
        case .swap: return "Two frames play. Mark every cell whose contents changed between them."
        case .difference: return "The recall board stays visible but altered. Find the changed cells."
        case .shape: return "Only the vertices are shown. Rebuild the complete structure they define."
        case .colors: return "Same symbol everywhere. Position and colour must both be right."
        case .symbols: return "Same colour everywhere. Position and symbol must both be right."
        case .multiStage: return "Several short boards in a row. Every stage adds to one total."
        case .size: return "Scale is the only cue. Recall each object's size class."
        case .direction: return "Recall which way every marker pointed."
        case .height: return "Recall the layer level each object occupied."
        case .dynamic: return "Objects drift across frames. Only the final position counts."
        case .fading: return "Objects fade out one by one. The vanished ones still count."
        }
    }
}

struct GameMode: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var type: GameModeType
}

enum GameState: String, Codable {
    case preview, playing, paused, finished
}

// MARK: - Paint attributes

enum PaintAttribute: Int, Codable, CaseIterable {
    case category = 0, color, symbol, size, direction, level
    var title: String {
        switch self {
        case .category: return "Class"
        case .color: return "Colour"
        case .symbol: return "Symbol"
        case .size: return "Size"
        case .direction: return "Direction"
        case .level: return "Layer"
        }
    }
}

// MARK: - Results and stats

struct GameResult: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var score: Int
    var accuracy: Double
    var duration: Double
    var modeRaw: Int
    var difficulty: Int
    var boardDimension: Int
    var date: Date
    var won: Bool
    var wasDaily: Bool

    var mode: GameModeType { GameModeType(rawValue: modeRaw) ?? .objects }
}

struct PlayerStats: Codable {
    var totalGames: Int = 0
    var bestScore: Int = 0
    var averageAccuracy: Double = 0
    var winStreak: Int = 0

    var bestStreak: Int = 0
    var perfectRounds: Int = 0
    var highAccuracyRounds: Int = 0
    var dailyCompleted: Int = 0
    var totalSeconds: Double = 0
    var favoritesCount: Int = 0
    var modeGames: [Int: Int] = [:]
    var sizesCleared: Set<Int> = []
    var difficultiesCleared: Set<Int> = []
    var themesUsed: Set<Int> = []
    var accuracySum: Double = 0

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalGames = try c.decodeIfPresent(Int.self, forKey: .totalGames) ?? 0
        bestScore = try c.decodeIfPresent(Int.self, forKey: .bestScore) ?? 0
        averageAccuracy = try c.decodeIfPresent(Double.self, forKey: .averageAccuracy) ?? 0
        winStreak = try c.decodeIfPresent(Int.self, forKey: .winStreak) ?? 0
        bestStreak = try c.decodeIfPresent(Int.self, forKey: .bestStreak) ?? 0
        perfectRounds = try c.decodeIfPresent(Int.self, forKey: .perfectRounds) ?? 0
        highAccuracyRounds = try c.decodeIfPresent(Int.self, forKey: .highAccuracyRounds) ?? 0
        dailyCompleted = try c.decodeIfPresent(Int.self, forKey: .dailyCompleted) ?? 0
        totalSeconds = try c.decodeIfPresent(Double.self, forKey: .totalSeconds) ?? 0
        favoritesCount = try c.decodeIfPresent(Int.self, forKey: .favoritesCount) ?? 0
        modeGames = try c.decodeIfPresent([Int: Int].self, forKey: .modeGames) ?? [:]
        sizesCleared = try c.decodeIfPresent(Set<Int>.self, forKey: .sizesCleared) ?? []
        difficultiesCleared = try c.decodeIfPresent(Set<Int>.self, forKey: .difficultiesCleared) ?? []
        themesUsed = try c.decodeIfPresent(Set<Int>.self, forKey: .themesUsed) ?? []
        accuracySum = try c.decodeIfPresent(Double.self, forKey: .accuracySum) ?? 0
    }

    var modesTried: Int { modeGames.filter { $0.value > 0 }.count }
    var totalMinutes: Int { Int(totalSeconds / 60.0) }
}

struct Achievement: Codable, Identifiable, Hashable {
    var id: UUID
    var unlocked: Bool
    var key: String
    var title: String
    var detail: String
    var group: String
}
