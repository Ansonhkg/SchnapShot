import Foundation

public struct GenerationPreset: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var prompt: String
    public var size: OutputSize

    public init(id: String = UUID().uuidString, name: String, prompt: String, size: OutputSize) {
        self.id = id; self.name = name; self.prompt = prompt; self.size = size
    }
    public static let thumbnail = GenerationPreset(id: "thumbnail", name: "Thumbnail",
        prompt: "Create a thumbnail from this image.", size: .social)
    public static let icon = GenerationPreset(id: "icon", name: "Icon",
        prompt: "Create a clean app icon inspired by this image. Use one recognizable symbol, a simple background, and no text. Keep it legible at small sizes.",
        size: .init(width: 1024, height: 1024))
    public var validationError: String? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name.count > 60 { return "Enter a preset name from 1 to 60 characters." }
        if prompt.isEmpty || prompt.count > 8_000 { return "Enter a prompt from 1 to 8,000 characters." }
        if !size.isValid { return "Use 64–4096 pixels per side, up to 8 MP and a maximum 3:1 ratio." }
        return nil
    }
    public var generationPrompt: String {
        "\(prompt.trimmingCharacters(in: .whitespacesAndNewlines))\n\nOutput size: \(size.width)x\(size.height) pixels. Aspect ratio: \(size.ratioLabel)."
    }
    public var normalized: GenerationPreset {
        .init(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
              prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines), size: size)
    }
}

public struct PresetLibrary: Codable, Equatable {
    public private(set) var presets: [GenerationPreset]
    public private(set) var selectedID: String
    public static let storageKey = "generationPresets.v1"
    public var selected: GenerationPreset { presets.first(where: { $0.id == selectedID }) ?? presets[0] }

    public init(legacySize: OutputSize = .social) {
        var thumbnail = GenerationPreset.thumbnail
        thumbnail.size = legacySize.isValid ? legacySize : .social
        presets = [thumbnail, .icon]; selectedID = thumbnail.id
    }
    public static func load(from defaults: UserDefaults) -> PresetLibrary {
        if let data = defaults.data(forKey: storageKey), let library = try? JSONDecoder().decode(Self.self, from: data),
           !library.presets.isEmpty, library.presets.allSatisfy({ $0.validationError == nil }),
           Set(library.presets.map(\.id)).count == library.presets.count,
           library.presets.contains(where: { $0.id == library.selectedID }) { return library }
        return .init(legacySize: .init(width: defaults.integer(forKey: "outputWidth"), height: defaults.integer(forKey: "outputHeight")))
    }
    public mutating func save(_ preset: GenerationPreset, to defaults: UserDefaults) throws {
        if let error = preset.validationError { throw ThumbnailError.message(error) }
        let preset = preset.normalized
        guard !presets.contains(where: { $0.id != preset.id && $0.name.caseInsensitiveCompare(preset.name) == .orderedSame }) else {
            throw ThumbnailError.message("That preset name is already used. Choose another name, or select the existing preset to edit it.")
        }
        var updated = self
        if let index = updated.presets.firstIndex(where: { $0.id == preset.id }) { updated.presets[index] = preset }
        else { updated.presets.append(preset) }
        updated.selectedID = preset.id
        let encoded = try JSONEncoder().encode(updated)
        defaults.set(encoded, forKey: Self.storageKey)
        self = updated
    }
    public mutating func select(_ id: String, to defaults: UserDefaults) throws {
        guard let preset = presets.first(where: { $0.id == id }) else { throw ThumbnailError.message("Preset not found.") }
        try save(preset, to: defaults)
    }
}
