import Foundation
import Carbon

public struct CaptureShortcut: Codable, Equatable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var keyLabel: String
    public init(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode; self.modifiers = modifiers; self.keyLabel = keyLabel
    }
    public static let standard = CaptureShortcut(keyCode: UInt32(kVK_ANSI_4), modifiers: UInt32(cmdKey | optionKey), keyLabel: "4")
    public var isValid: Bool {
        keyCode < 128 && modifiers & UInt32(cmdKey | controlKey | optionKey) != 0 && !keyLabel.isEmpty
            && modifiers & ~UInt32(cmdKey | controlKey | optionKey | shiftKey) == 0
    }
    public var label: String {
        [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")]
            .filter { modifiers & UInt32($0.0) != 0 }.map(\.1).joined() + keyLabel
    }
    public static func load(from defaults: UserDefaults) -> Self {
        guard let data = defaults.data(forKey: "captureShortcut.v1"),
              let value = try? JSONDecoder().decode(Self.self, from: data), value.isValid else { return .standard }
        return value
    }
    public func save(to defaults: UserDefaults) throws {
        guard isValid else { throw ThumbnailError.message("Include Command, Option, or Control with a key.") }
        defaults.set(try JSONEncoder().encode(self), forKey: "captureShortcut.v1")
    }
}
