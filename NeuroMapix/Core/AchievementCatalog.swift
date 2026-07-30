import Foundation

enum AchievementCondition: Hashable {
    case totalGames(Int)
    case bestScore(Int)
    case winStreak(Int)
    case averageAccuracy(Double)
    case perfectRounds(Int)
    case modeGames(GameModeType, Int)
    case sizeCleared(BoardSize)
    case difficultyCleared(Int)
    case dailyCompleted(Int)
    case themesUsed(Int)
    case favorites(Int)
    case totalMinutes(Int)
    case modesTried(Int)
    case highAccuracyRounds(Int)

    /// Stable, unique text form — also used as the achievement key.
    var key: String {
        switch self {
        case .totalGames(let n): return "games.\(n)"
        case .bestScore(let n): return "score.\(n)"
        case .winStreak(let n): return "streak.\(n)"
        case .averageAccuracy(let v): return "avgacc.\(Int(v * 100))"
        case .perfectRounds(let n): return "perfect.\(n)"
        case .modeGames(let m, let n): return "mode.\(m.rawValue).\(n)"
        case .sizeCleared(let s): return "board.\(s.dimension)"
        case .difficultyCleared(let d): return "difficulty.\(d)"
        case .dailyCompleted(let n): return "daily.\(n)"
        case .themesUsed(let n): return "themes.\(n)"
        case .favorites(let n): return "favorites.\(n)"
        case .totalMinutes(let n): return "minutes.\(n)"
        case .modesTried(let n): return "modes.\(n)"
        case .highAccuracyRounds(let n): return "sharp.\(n)"
        }
    }

    var group: String {
        switch self {
        case .totalGames: return "Volume"
        case .bestScore: return "Records"
        case .winStreak: return "Streaks"
        case .averageAccuracy, .highAccuracyRounds: return "Precision"
        case .perfectRounds: return "Precision"
        case .modeGames: return "Modes"
        case .sizeCleared: return "Boards"
        case .difficultyCleared: return "Difficulty"
        case .dailyCompleted: return "Daily"
        case .themesUsed: return "Library"
        case .favorites: return "Library"
        case .totalMinutes: return "Training Time"
        case .modesTried: return "Modes"
        }
    }

    var detail: String {
        switch self {
        case .totalGames(let n): return "Finish \(n) session\(n == 1 ? "" : "s")."
        case .bestScore(let n): return "Record a single score of \(n) or more."
        case .winStreak(let n): return "Reach a win streak of \(n)."
        case .averageAccuracy(let v): return "Hold a lifetime average accuracy of \(Int(v * 100))%."
        case .perfectRounds(let n): return "Finish \(n) round\(n == 1 ? "" : "s") at 100% accuracy."
        case .modeGames(let m, let n): return "Play \(m.title) \(n) times."
        case .sizeCleared(let s): return "Win a round on the \(s.label) board."
        case .difficultyCleared(let d): return "Win a round at difficulty \(d) (\(DifficultyProfile(level: d).name))."
        case .dailyCompleted(let n): return "Complete \(n) daily challenge\(n == 1 ? "" : "s")."
        case .themesUsed(let n): return "Try \(n) visual themes."
        case .favorites(let n): return "Keep \(n) layout\(n == 1 ? "" : "s") in Favorites."
        case .totalMinutes(let n): return "Train for \(n) minutes in total."
        case .modesTried(let n): return "Play \(n) different modes."
        case .highAccuracyRounds(let n): return "Finish \(n) rounds at 90% accuracy or better."
        }
    }

    func isSatisfied(by stats: PlayerStats) -> Bool {
        switch self {
        case .totalGames(let n): return stats.totalGames >= n
        case .bestScore(let n): return stats.bestScore >= n
        case .winStreak(let n): return stats.bestStreak >= n
        case .averageAccuracy(let v): return stats.totalGames > 0 && stats.averageAccuracy >= v
        case .perfectRounds(let n): return stats.perfectRounds >= n
        case .modeGames(let m, let n): return (stats.modeGames[m.rawValue] ?? 0) >= n
        case .sizeCleared(let s): return stats.sizesCleared.contains(s.dimension)
        case .difficultyCleared(let d): return stats.difficultiesCleared.contains(d)
        case .dailyCompleted(let n): return stats.dailyCompleted >= n
        case .themesUsed(let n): return stats.themesUsed.count >= n
        case .favorites(let n): return stats.favoritesCount >= n
        case .totalMinutes(let n): return stats.totalMinutes >= n
        case .modesTried(let n): return stats.modesTried >= n
        case .highAccuracyRounds(let n): return stats.highAccuracyRounds >= n
        }
    }
}

struct AchievementDefinition: Identifiable {
    let condition: AchievementCondition
    let title: String
    var id: String { condition.key }
    var key: String { condition.key }
    var detail: String { condition.detail }
    var group: String { condition.group }
}

enum AchievementCatalog {

    static let all: [AchievementDefinition] = build()

    private static func build() -> [AchievementDefinition] {
        var out: [AchievementDefinition] = []

        let volumeNames = ["First Trace", "Warm Circuit", "Ten Boards", "Quarter Set", "Half Century",
                           "Century Mind", "Two Hundred", "Deep Bench", "Five Hundred",
                           "Seven Fifty", "Thousand Grid"]
        let volumeSteps = [1, 5, 10, 25, 50, 100, 200, 350, 500, 750, 1000]
        for (i, n) in volumeSteps.enumerated() {
            out.append(AchievementDefinition(condition: .totalGames(n), title: volumeNames[i]))
        }

        let scoreNames = ["Opening Mark", "Solid Mark", "Strong Mark", "High Mark", "Four Figures",
                          "Rising Record", "Sharp Record", "Two Thousand", "Elite Record", "Peak Record"]
        let scoreSteps = [200, 400, 600, 800, 1000, 1300, 1600, 2000, 2500, 3000]
        for (i, n) in scoreSteps.enumerated() {
            out.append(AchievementDefinition(condition: .bestScore(n), title: scoreNames[i]))
        }

        let streakNames = ["Back to Back", "Triple Lock", "Five Straight", "Eight Straight",
                           "Dozen Run", "Sixteen Run", "Twenty Run", "Long Chain", "Unbroken"]
        let streakSteps = [2, 3, 5, 8, 12, 16, 20, 25, 30]
        for (i, n) in streakSteps.enumerated() {
            out.append(AchievementDefinition(condition: .winStreak(n), title: streakNames[i]))
        }

        let accNames = ["Half Clear", "Steady Eye", "Seven Tenths", "Eight Tenths",
                        "Fine Tuned", "Near Perfect", "Immaculate Average"]
        let accSteps = [0.5, 0.6, 0.7, 0.8, 0.85, 0.9, 0.95]
        for (i, v) in accSteps.enumerated() {
            out.append(AchievementDefinition(condition: .averageAccuracy(v), title: accNames[i]))
        }

        let perfectNames = ["Clean Sheet", "Triple Clean", "Five Clean", "Ten Clean", "Twenty Clean",
                            "Thirty Five Clean", "Fifty Clean", "Seventy Five Clean", "Hundred Clean"]
        let perfectSteps = [1, 3, 5, 10, 20, 35, 50, 75, 100]
        for (i, n) in perfectSteps.enumerated() {
            out.append(AchievementDefinition(condition: .perfectRounds(n), title: perfectNames[i]))
        }

        for mode in GameModeType.allCases {
            out.append(AchievementDefinition(condition: .modeGames(mode, 5),
                                             title: "\(mode.short) Adept"))
            out.append(AchievementDefinition(condition: .modeGames(mode, 25),
                                             title: "\(mode.short) Master"))
        }

        for size in BoardSize.allCases {
            out.append(AchievementDefinition(condition: .sizeCleared(size),
                                             title: "\(size.label) Cleared"))
        }

        for d in DifficultyProfile.minLevel...DifficultyProfile.maxLevel {
            out.append(AchievementDefinition(condition: .difficultyCleared(d),
                                             title: "\(DifficultyProfile(level: d).name) Cleared"))
        }

        let dailyNames = ["Daily Start", "Three Days", "Full Week", "Fortnight",
                          "Thirty Dailies", "Sixty Dailies", "Hundred Dailies"]
        let dailySteps = [1, 3, 7, 14, 30, 60, 100]
        for (i, n) in dailySteps.enumerated() {
            out.append(AchievementDefinition(condition: .dailyCompleted(n), title: dailyNames[i]))
        }

        let themeNames = ["Two Palettes", "Four Palettes", "Six Palettes", "Nine Palettes", "Full Palette Set"]
        let themeSteps = [2, 4, 6, 9, 12]
        for (i, n) in themeSteps.enumerated() {
            out.append(AchievementDefinition(condition: .themesUsed(n), title: themeNames[i]))
        }

        let favNames = ["First Favorite", "Three Favorites", "Five Favorites", "Ten Favorites", "Twenty Favorites"]
        let favSteps = [1, 3, 5, 10, 20]
        for (i, n) in favSteps.enumerated() {
            out.append(AchievementDefinition(condition: .favorites(n), title: favNames[i]))
        }

        let minuteNames = ["Ten Minutes", "Half Hour", "One Hour", "Two Hours", "Five Hours", "Ten Hours"]
        let minuteSteps = [10, 30, 60, 120, 300, 600]
        for (i, n) in minuteSteps.enumerated() {
            out.append(AchievementDefinition(condition: .totalMinutes(n), title: minuteNames[i]))
        }

        let variedNames = ["Five Modes", "Ten Modes", "Fifteen Modes", "All Twenty Modes"]
        let variedSteps = [5, 10, 15, 20]
        for (i, n) in variedSteps.enumerated() {
            out.append(AchievementDefinition(condition: .modesTried(n), title: variedNames[i]))
        }

        let sharpNames = ["Five Sharp Rounds", "Fifteen Sharp Rounds", "Forty Sharp Rounds"]
        let sharpSteps = [5, 15, 40]
        for (i, n) in sharpSteps.enumerated() {
            out.append(AchievementDefinition(condition: .highAccuracyRounds(n), title: sharpNames[i]))
        }

        return out
    }

    static var groups: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for d in all where seen.insert(d.group).inserted { out.append(d.group) }
        return out
    }

    /// A plausible fully-trained player. Used to prove nothing is unreachable.
    static func maximalState() -> PlayerStats {
        var s = PlayerStats()
        s.totalGames = 1500
        s.bestScore = 5000
        s.averageAccuracy = 0.99
        s.winStreak = 45
        s.bestStreak = 45
        s.perfectRounds = 250
        s.highAccuracyRounds = 600
        s.dailyCompleted = 180
        s.totalSeconds = 900 * 60
        s.favoritesCount = 40
        for m in GameModeType.allCases { s.modeGames[m.rawValue] = 60 }
        s.sizesCleared = Set(BoardSize.allCases.map { $0.dimension })
        s.difficultiesCleared = Set(DifficultyProfile.minLevel...DifficultyProfile.maxLevel)
        s.themesUsed = Set(0..<12)
        return s
    }

    static func evaluate(stats: PlayerStats, existing: [String: Achievement]) -> [Achievement] {
        all.map { def in
            let already = existing[def.key]?.unlocked ?? false
            return Achievement(id: existing[def.key]?.id ?? UUID(),
                               unlocked: already || def.condition.isSatisfied(by: stats),
                               key: def.key,
                               title: def.title,
                               detail: def.detail,
                               group: def.group)
        }
    }
}
