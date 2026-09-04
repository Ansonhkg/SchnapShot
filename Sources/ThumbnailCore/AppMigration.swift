import Foundation

/// The only legacy names retained are upgrade inputs; never used as UI branding.
public enum AppMigration {
    public static let legacyName = "CmdShift4"
    public static let legacyDomain = "com.anson.cmdshift4"
    public static func preparePreferences(_ defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: "SchnapShot.migratedPreferences") else { return }
        let old = defaults.persistentDomain(forName: legacyDomain) ?? [:]
        for key in [PresetLibrary.storageKey, "captureShortcut.v1", "outputWidth", "outputHeight"] {
            if defaults.object(forKey: key) == nil, let value = old[key] { defaults.set(value, forKey: key) }
        }
        defaults.set(true, forKey: "SchnapShot.migratedPreferences")
    }
    public static func storage(in root: URL) throws -> (storage: URL, codexHome: URL) {
        let fm = FileManager.default
        let old = root.appendingPathComponent(legacyName, isDirectory: true)
        let new = root.appendingPathComponent("SchnapShot", isDirectory: true)
        let oldExists = fm.fileExists(atPath: old.path)
        if oldExists && !fm.fileExists(atPath: new.path) {
            try fm.moveItem(at: old, to: new)
            do { try fm.createSymbolicLink(at: old, withDestinationURL: new) }
            catch { try? fm.moveItem(at: new, to: old); throw error }
        }
        try fm.createDirectory(at: new, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        // Codex scopes Keychain credentials to its home path. Preserve the old home alias for upgrades.
        let existingLogin = old.appendingPathComponent("Codex", isDirectory: true)
        return (new, fm.fileExists(atPath: existingLogin.path) ? existingLogin : new.appendingPathComponent("Codex", isDirectory: true))
    }
}
