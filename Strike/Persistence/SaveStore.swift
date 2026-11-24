import Foundation
import os

/// Reads and writes `save.json` in Application Support (the directory is injectable for tests).
/// Never crashes on bad data: a corrupt file or an unknown version is moved to `save.bak.json`
/// and `load()` returns nil (fresh start). Saved on level complete, checkpoint touch and app
/// background (pass B wires the triggers).
nonisolated final class SaveStore: Sendable {
    static let fileName = "save.json"
    static let backupName = "save.bak.json"

    let directory: URL
    var fileURL: URL { directory.appendingPathComponent(Self.fileName) }
    var backupURL: URL { directory.appendingPathComponent(Self.backupName) }

    private static let log = Logger(subsystem: "io.schervan.strike", category: "save")

    init(directory: URL) {
        self.directory = directory
    }

    /// `<Application Support>/Strike/`.
    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Strike", isDirectory: true)
    }

    static func makeDefault() -> SaveStore { SaveStore(directory: defaultDirectory()) }

    var hasSave: Bool { FileManager.default.fileExists(atPath: fileURL.path) }

    /// The saved game, or nil when there is none or it could not be read (then moved aside).
    func load() -> SaveGame? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = Self.decoder()
        guard let probe = try? decoder.decode(VersionProbe.self, from: data) else {
            quarantine(reason: "not a save file")
            return nil
        }
        guard probe.version == SaveGame.currentVersion else {
            quarantine(reason: "version \(probe.version), expected \(SaveGame.currentVersion)")
            return nil
        }
        do {
            return try decoder.decode(SaveGame.self, from: data)
        } catch {
            quarantine(reason: String(describing: error))
            return nil
        }
    }

    /// Atomic write (temp file + rename), creating the directory if needed.
    func save(_ game: SaveGame) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.encoder().encode(game)
        try data.write(to: fileURL, options: .atomic)
    }

    /// New game: removes the save (the backup stays).
    func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func quarantine(reason: String) {
        Self.log.error("save.json unreadable (\(reason, privacy: .public)), moved to \(Self.backupName, privacy: .public)")
        let fm = FileManager.default
        try? fm.removeItem(at: backupURL)
        do {
            try fm.moveItem(at: fileURL, to: backupURL)
        } catch {
            try? fm.removeItem(at: fileURL)
        }
    }

    private struct VersionProbe: Decodable {
        let version: Int
    }

    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }

    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
