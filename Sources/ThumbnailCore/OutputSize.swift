import Foundation

public struct OutputSize: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int
    public static let social = OutputSize(width: 1200, height: 630)
    public static let presets: [(String, OutputSize)] = [
        ("1200 × 630", .social),
        ("16:9", .init(width: 1920, height: 1080)),
        ("1:1", .init(width: 1080, height: 1080)),
        ("9:16", .init(width: 1080, height: 1920))
    ]
    public init(width: Int, height: Int) { self.width = width; self.height = height }
    public var label: String { "\(width) × \(height)" }
    public var ratioLabel: String {
        guard width > 0, height > 0 else { return "—" }
        var a = width, b = height
        while b != 0 { let remainder = a % b; a = b; b = remainder }
        return "\(width / a):\(height / a)"
    }
    public var prompt: String { "Create a thumbnail from this image, \(width)x\(height)." }
    public var isValid: Bool {
        (64...4096).contains(width) && (64...4096).contains(height)
            && width * height <= 8_388_608
            && max(Double(width) / Double(height), Double(height) / Double(width)) <= 3
    }
}

public enum ThumbnailError: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
