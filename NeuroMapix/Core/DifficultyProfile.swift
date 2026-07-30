import Foundation

/// A single difficulty step drives every knob at once: board size, object count,
/// preview time, frame speed, stage count, decoys, and whether the board is
/// mirrored / rotated / animated.
struct DifficultyProfile {
    static let minLevel = 1
    static let maxLevel = 7

    let level: Int

    init(level: Int) {
        self.level = min(max(level, DifficultyProfile.minLevel), DifficultyProfile.maxLevel)
    }

    private var index: Int { level - 1 }

    var name: String {
        ["Calm", "Light", "Steady", "Focused", "Sharp", "Intense", "Extreme"][index]
    }

    /// Strictly increasing.
    var boardSize: BoardSize { BoardSize.forDifficulty(level) }
    var boardDimension: Int { boardSize.dimension }

    /// Strictly increasing.
    var objectCount: Int { [3, 4, 6, 8, 10, 13, 16][index] }

    /// Strictly decreasing.
    var previewSeconds: Double { [12.0, 10.5, 9.0, 7.5, 6.5, 5.5, 5.0][index] }

    /// Strictly decreasing — how long each animation frame is held.
    var frameInterval: Double { [1.20, 1.05, 0.95, 0.85, 0.75, 0.65, 0.55][index] }

    /// Non-decreasing.
    var stageCount: Int { [1, 1, 2, 2, 3, 3, 4][index] }

    /// Strictly increasing.
    var decoyCount: Int { [0, 1, 2, 3, 4, 5, 6][index] }

    /// Strictly decreasing — recall time budget, also the speed term of the score.
    var timeLimit: Double { [60, 55, 50, 45, 40, 35, 30][index] }

    /// Non-decreasing — how many attribute options the paint palettes offer.
    var paletteWidth: Int { [2, 3, 3, 4, 4, 5, 6][index] }

    /// Non-decreasing — moving pieces in dynamic mode.
    var movingCount: Int { [1, 1, 2, 2, 3, 3, 4][index] }

    /// Non-decreasing — how many frames a dynamic/fading preview plays.
    var frameCount: Int { [2, 3, 3, 4, 4, 5, 5][index] }

    var appliesMirror: Bool { level >= 2 }
    var appliesRotation: Bool { level >= 3 }
    var appliesDynamic: Bool { level >= 2 }

    static var all: [DifficultyProfile] {
        (minLevel...maxLevel).map { DifficultyProfile(level: $0) }
    }
}
