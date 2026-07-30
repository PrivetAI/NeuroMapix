import Foundation

/// The app ships in English (US) only, so every date it keys or prints uses the
/// Gregorian calendar and a fixed locale. Reading `Calendar.current` here would
/// print Buddhist or Hijri years on devices set to those regions.
enum AppCalendar {
    static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone.current
        return calendar
    }()

    static func formatter(date: DateFormatter.Style, time: DateFormatter.Style) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = gregorian
        f.locale = Locale(identifier: "en_US")
        f.dateStyle = date
        f.timeStyle = time
        return f
    }
}

/// Generated purely from the device date — no network, no server.
struct DailyChallenge {
    let dateKey: String
    let mode: GameModeType
    let difficulty: Int
    let layout: BoardLayout
    let size: BoardSize
    let seed: UInt64

    static func dateKey(for date: Date, calendar: Calendar = AppCalendar.gregorian) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1)
    }

    /// Depends on the calendar date and nothing else — not on how far the player has
    /// progressed — so the promise "the same puzzle all day" actually holds.
    static func forDate(_ date: Date, calendar: Calendar = AppCalendar.gregorian) -> DailyChallenge {
        let key = dateKey(for: date, calendar: calendar)
        var hash: UInt64 = 0xCBF29CE484222325
        for byte in key.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001B3 }
        var rng = SeededRandom(seed: hash)

        let mode = GameModeType.allCases[rng.int(GameModeType.allCases.count)]
        let difficulty = rng.int(in: 2...5)
        let size = BoardSize.forDifficulty(difficulty)
        let candidates = LayoutCatalog.layouts(for: size)
        let layout = candidates.isEmpty ? LayoutCatalog.all[0] : candidates[rng.int(candidates.count)]

        return DailyChallenge(dateKey: key, mode: mode, difficulty: difficulty,
                              layout: layout, size: size, seed: hash)
    }

    var title: String { "\(mode.title) · \(size.label) · \(DifficultyProfile(level: difficulty).name)" }
}
