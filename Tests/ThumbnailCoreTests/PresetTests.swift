import XCTest
@testable import ThumbnailCore

final class PresetTests: XCTestCase {
    private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let name = "SchnapShot.PresetTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    func testBuiltinsAndPrompt() {
        let library = PresetLibrary()
        XCTAssertEqual(library.selected, .thumbnail)
        XCTAssertEqual(library.presets.count, 2)
        XCTAssertEqual(GenerationPreset.icon.size.ratioLabel, "1:1")
        XCTAssertEqual(OutputSize.social.ratioLabel, "40:21")
        XCTAssertTrue(GenerationPreset.icon.generationPrompt.contains("1024x1024"))
        XCTAssertFalse(GenerationPreset.icon.generationPrompt.contains("thumbnail"))
    }
    func testSelectionPersistsWithoutChangingPresetContents() throws {
        try withDefaults { defaults in
            var library = PresetLibrary()
            let original = library.presets
            try library.select("icon", to: defaults)
            XCTAssertEqual(library.presets, original)
            XCTAssertEqual(PresetLibrary.load(from: defaults).selected, .icon)
            XCTAssertThrowsError(try library.select("missing", to: defaults))
            XCTAssertEqual(library.selected, .icon)
        }
    }
    func testShortcutPersistenceAndValidation() throws {
        try withDefaults { defaults in
            XCTAssertEqual(CaptureShortcut.load(from: defaults), .standard)
            XCTAssertEqual(CaptureShortcut.standard.label, "⌥⌘4")
            var value = CaptureShortcut.standard
            value.keyCode = 20; value.keyLabel = "3"
            try value.save(to: defaults)
            XCTAssertEqual(CaptureShortcut.load(from: defaults), value)
            value.modifiers = 0
            XCTAssertFalse(value.isValid)
            XCTAssertThrowsError(try value.save(to: defaults))
            defaults.set(Data("invalid".utf8), forKey: "captureShortcut.v1")
            XCTAssertEqual(CaptureShortcut.load(from: defaults), .standard)
        }
    }

    func testSaveReloadAndEdit() throws {
        try withDefaults { defaults in
            var library = PresetLibrary.load(from: defaults)
            var preset = GenerationPreset(name: " My icon ", prompt: " Draw an icon ", size: .init(width: 512, height: 512))
            try library.save(preset, to: defaults)
            XCTAssertEqual(library.selected.name, "My icon")
            XCTAssertEqual(library.selected.prompt, "Draw an icon")
            XCTAssertEqual(PresetLibrary.load(from: defaults), library)
            preset.prompt = "Create a blue icon"
            try library.save(preset, to: defaults)
            XCTAssertEqual(library.presets.count, 3)
            XCTAssertEqual(PresetLibrary.load(from: defaults).selected.prompt, preset.prompt)
        }
    }

    func testDuplicateAndInvalidSavePreserveLibrary() throws {
        try withDefaults { defaults in
            var library = PresetLibrary()
            try library.save(.icon, to: defaults)
            let previous = library
            XCTAssertThrowsError(try library.save(.init(name: " icon ", prompt: "Draw", size: .social), to: defaults))
            XCTAssertThrowsError(try library.save(.init(name: "Empty", prompt: " \n", size: .social), to: defaults))
            XCTAssertThrowsError(try library.save(.init(name: "Invalid", prompt: "Draw", size: .init(width: 0, height: 0)), to: defaults))
            XCTAssertEqual(library, previous)
            XCTAssertEqual(PresetLibrary.load(from: defaults), previous)
        }
    }

    func testLegacyMigrationAndCorruptStorage() {
        withDefaults { defaults in
            defaults.set(1920, forKey: "outputWidth")
            defaults.set(1080, forKey: "outputHeight")
            XCTAssertEqual(PresetLibrary.load(from: defaults).selected.size, .init(width: 1920, height: 1080))
            defaults.set(Data("{\"presets\":[],\"selectedID\":\"missing\"}".utf8), forKey: PresetLibrary.storageKey)
            XCTAssertEqual(PresetLibrary.load(from: defaults).presets.count, 2)
            defaults.set(-1, forKey: "outputWidth")
            XCTAssertEqual(PresetLibrary.load(from: defaults).selected.size, .social)
        }
    }
}
