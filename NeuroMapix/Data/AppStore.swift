import Foundation
import Combine

struct AppSettings {
    var themeID: Int = 0
    var darkMode: Bool = false
    var soundOn: Bool = false
    var hapticsOn: Bool = true
    var defaultModeRaw: Int = GameModeType.objects.rawValue
    var defaultDifficulty: Int = 2
    var defaultSizeRaw: Int = BoardSize.x4.rawValue
    var showCoordinates: Bool = false
    var language: String = "English (US)"
}

@MainActor
final class AppStore: ObservableObject {

    @Published var settings = AppSettings()
    @Published var stats = PlayerStats()
    @Published var history: [GameResult] = []
    @Published var achievements: [Achievement] = []
    @Published var favorites: [Int] = []
    @Published var lastBackupInfo: String = "No backup yet"
    @Published var statusMessage: String?

    private let defaults = UserDefaults.standard
    private enum Key {
        static let theme = "nmx.themeID"
        static let dark = "nmx.darkMode"
        static let sound = "nmx.soundOn"
        static let haptics = "nmx.hapticsOn"
        static let mode = "nmx.defaultMode"
        static let difficulty = "nmx.defaultDifficulty"
        static let size = "nmx.defaultSize"
        static let coords = "nmx.showCoordinates"
        static let installed = "nmx.installed"
        static let dailyDone = "nmx.dailyDoneKeys"
    }

    init() {
        loadSettings()
        loadData()
        refreshBackupInfo()
        refreshAchievements()
    }

    // MARK: - Settings

    private func loadSettings() {
        if defaults.object(forKey: Key.installed) == nil {
            defaults.set(true, forKey: Key.installed)
            saveSettings()
            return
        }
        settings.themeID = defaults.integer(forKey: Key.theme)
        settings.darkMode = defaults.bool(forKey: Key.dark)
        settings.soundOn = defaults.bool(forKey: Key.sound)
        settings.hapticsOn = defaults.object(forKey: Key.haptics) as? Bool ?? true
        settings.defaultModeRaw = defaults.integer(forKey: Key.mode)
        let d = defaults.integer(forKey: Key.difficulty)
        settings.defaultDifficulty = d == 0 ? 2 : d
        let s = defaults.integer(forKey: Key.size)
        settings.defaultSizeRaw = BoardSize(rawValue: s) == nil ? BoardSize.x4.rawValue : s
        settings.showCoordinates = defaults.bool(forKey: Key.coords)
    }

    func saveSettings() {
        defaults.set(settings.themeID, forKey: Key.theme)
        defaults.set(settings.darkMode, forKey: Key.dark)
        defaults.set(settings.soundOn, forKey: Key.sound)
        defaults.set(settings.hapticsOn, forKey: Key.haptics)
        defaults.set(settings.defaultModeRaw, forKey: Key.mode)
        defaults.set(settings.defaultDifficulty, forKey: Key.difficulty)
        defaults.set(settings.defaultSizeRaw, forKey: Key.size)
        defaults.set(settings.showCoordinates, forKey: Key.coords)
    }

    var theme: VisualTheme { ThemeCatalog.theme(id: settings.themeID) }
    var palette: Palette { Palette(theme: theme, isDark: settings.darkMode) }

    func selectTheme(_ id: Int) {
        settings.themeID = id
        stats.themesUsed.insert(id)
        saveSettings()
        persistStats()
        refreshAchievements()
    }

    func setDarkMode(_ on: Bool) {
        settings.darkMode = on
        saveSettings()
    }

    // MARK: - Data

    private func loadData() {
        stats = Persistence.load(PlayerStats.self, from: Persistence.statsFile) ?? PlayerStats()
        history = Persistence.load([GameResult].self, from: Persistence.historyFile) ?? []
        let stored = Persistence.load([Achievement].self, from: Persistence.achievementsFile) ?? []
        achievements = stored
        favorites = Persistence.load([Int].self, from: Persistence.favoritesFile) ?? []
        stats.themesUsed.insert(settings.themeID)
        stats.favoritesCount = favorites.count
    }

    private func persistStats() { Persistence.save(stats, to: Persistence.statsFile) }
    private func persistHistory() { Persistence.save(history, to: Persistence.historyFile) }
    private func persistAchievements() { Persistence.save(achievements, to: Persistence.achievementsFile) }
    private func persistFavorites() { Persistence.save(favorites, to: Persistence.favoritesFile) }

    func refreshAchievements() {
        var index: [String: Achievement] = [:]
        for a in achievements { index[a.key] = a }
        achievements = AchievementCatalog.evaluate(stats: stats, existing: index)
        persistAchievements()
    }

    var unlockedCount: Int { achievements.filter { $0.unlocked }.count }

    // MARK: - Recording a finished session

    /// Autosaved immediately after every finished session.
    func record(result: GameResult) {
        stats.totalGames += 1
        stats.accuracySum += result.accuracy
        stats.averageAccuracy = stats.accuracySum / Double(stats.totalGames)
        stats.totalSeconds += result.duration
        stats.modeGames[result.modeRaw] = (stats.modeGames[result.modeRaw] ?? 0) + 1
        if result.score > stats.bestScore { stats.bestScore = result.score }
        if result.accuracy >= 0.999 { stats.perfectRounds += 1 }
        if result.accuracy >= 0.9 { stats.highAccuracyRounds += 1 }
        if result.won {
            stats.winStreak += 1
            stats.bestStreak = max(stats.bestStreak, stats.winStreak)
            stats.sizesCleared.insert(result.boardDimension)
            stats.difficultiesCleared.insert(result.difficulty)
        } else {
            stats.winStreak = 0
        }
        if result.wasDaily && result.won {
            stats.dailyCompleted += 1
            markDailyDone()
        }
        history.insert(result, at: 0)
        if history.count > 400 { history = Array(history.prefix(400)) }

        persistStats()
        persistHistory()
        refreshAchievements()
    }

    // MARK: - Board unlocking

    func isUnlocked(_ size: BoardSize) -> Bool { stats.totalGames >= size.unlockGames }

    var highestUnlockedTier: Int {
        BoardSize.allCases.filter { isUnlocked($0) }.map { $0.tierIndex }.max() ?? 0
    }

    func unlockHint(_ size: BoardSize) -> String {
        let missing = max(0, size.unlockGames - stats.totalGames)
        return missing == 0 ? "" : "\(missing) more session\(missing == 1 ? "" : "s")"
    }

    // MARK: - Favorites

    func isFavorite(_ layoutID: Int) -> Bool { favorites.contains(layoutID) }

    func toggleFavorite(_ layoutID: Int) {
        if let i = favorites.firstIndex(of: layoutID) {
            favorites.remove(at: i)
        } else {
            favorites.append(layoutID)
        }
        stats.favoritesCount = favorites.count
        persistFavorites()
        persistStats()
        refreshAchievements()
    }

    // MARK: - Daily

    func dailyDoneKeys() -> [String] { defaults.stringArray(forKey: Key.dailyDone) ?? [] }

    func isDailyDone(_ key: String) -> Bool { dailyDoneKeys().contains(key) }

    private func markDailyDone() {
        let key = DailyChallenge.dateKey(for: Date())
        var keys = dailyDoneKeys()
        if !keys.contains(key) {
            keys.append(key)
            if keys.count > 400 { keys = Array(keys.suffix(400)) }
            defaults.set(keys, forKey: Key.dailyDone)
        }
    }

    // MARK: - Backup / restore / reset

    func refreshBackupInfo() {
        if let date = Persistence.modifiedDate(Persistence.backupFile),
           let size = Persistence.fileSize(Persistence.backupFile) {
            let f = AppCalendar.formatter(date: .medium, time: .short)
            lastBackupInfo = "\(f.string(from: date)) · \(size) bytes"
        } else {
            lastBackupInfo = "No backup yet"
        }
    }

    func createBackup(label: String, note: String) -> Bool {
        let payload = Persistence.BackupPayload(version: 1,
                                               createdAt: Date(),
                                               label: label.isEmpty ? "Manual backup" : label,
                                               note: note,
                                               stats: stats,
                                               history: history,
                                               achievements: achievements,
                                               favorites: favorites,
                                               themeID: settings.themeID,
                                               darkMode: settings.darkMode)
        let ok = Persistence.writeBackup(payload)
        refreshBackupInfo()
        statusMessage = ok ? "Backup written to backup.mem" : "Could not write the backup"
        return ok
    }

    func backupDetails() -> Persistence.BackupPayload? { Persistence.readBackup() }

    func restoreBackup() -> Bool {
        guard let payload = Persistence.readBackup() else {
            statusMessage = "No backup file found"
            return false
        }
        stats = payload.stats
        history = payload.history
        favorites = payload.favorites
        settings.themeID = payload.themeID
        settings.darkMode = payload.darkMode
        var index: [String: Achievement] = [:]
        for a in payload.achievements { index[a.key] = a }
        achievements = AchievementCatalog.evaluate(stats: stats, existing: index)
        saveSettings()
        persistStats()
        persistHistory()
        persistFavorites()
        persistAchievements()
        statusMessage = "Restored \(payload.label)"
        return true
    }

    func resetAll() {
        stats = PlayerStats()
        history = []
        favorites = []
        stats.themesUsed.insert(settings.themeID)
        Persistence.delete(Persistence.statsFile)
        Persistence.delete(Persistence.historyFile)
        Persistence.delete(Persistence.favoritesFile)
        Persistence.delete(Persistence.achievementsFile)
        defaults.removeObject(forKey: Key.dailyDone)
        achievements = AchievementCatalog.evaluate(stats: stats, existing: [:])
        persistStats()
        persistHistory()
        persistFavorites()
        persistAchievements()
        statusMessage = "All progress cleared"
    }

    func deleteBackup() {
        Persistence.delete(Persistence.backupFile)
        refreshBackupInfo()
        statusMessage = "Backup file removed"
    }

    // MARK: - Derived statistics

    var recentResults: [GameResult] { Array(history.prefix(24)) }

    func averageAccuracy(for mode: GameModeType) -> Double? {
        let matching = history.filter { $0.modeRaw == mode.rawValue }
        guard !matching.isEmpty else { return nil }
        return matching.reduce(0.0) { $0 + $1.accuracy } / Double(matching.count)
    }

    func bestScore(for mode: GameModeType) -> Int? {
        history.filter { $0.modeRaw == mode.rawValue }.map { $0.score }.max()
    }

    func countByDifficulty() -> [Int: Int] {
        var out: [Int: Int] = [:]
        for r in history { out[r.difficulty, default: 0] += 1 }
        return out
    }
}
