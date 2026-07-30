import Foundation

/// All player data lives in JSON files under the app's Documents directory.
/// Nothing leaves the device.
enum Persistence {

    static let statsFile = "stats.json"
    static let historyFile = "history.json"
    static let achievementsFile = "achievements.json"
    static let favoritesFile = "favorites.json"
    static let backupFile = "backup.mem"

    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func url(_ name: String) -> URL { documents.appendingPathComponent(name) }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    @discardableResult
    static func save<T: Encodable>(_ value: T, to name: String) -> Bool {
        do {
            let data = try encoder.encode(value)
            try data.write(to: url(name), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: url(name))
    }

    static func fileSize(_ name: String) -> Int? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url(name).path)
        return attrs?[.size] as? Int
    }

    static func modifiedDate(_ name: String) -> Date? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url(name).path)
        return attrs?[.modificationDate] as? Date
    }

    static func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: url(name).path)
    }

    // MARK: - Backup payload

    struct BackupPayload: Codable {
        var version: Int
        var createdAt: Date
        var label: String
        var note: String
        var stats: PlayerStats
        var history: [GameResult]
        var achievements: [Achievement]
        var favorites: [Int]
        var themeID: Int
        var darkMode: Bool
    }

    static func writeBackup(_ payload: BackupPayload) -> Bool {
        save(payload, to: backupFile)
    }

    static func readBackup() -> BackupPayload? {
        load(BackupPayload.self, from: backupFile)
    }
}
