import Foundation

public struct JSONLineBuffer {
    private var data = Data()
    public init() {}
    public mutating func append(_ chunk: Data) throws -> [[String: Any]] {
        data.append(chunk)
        guard data.count < 80_000_000 else { throw ThumbnailError.message("Codex returned an oversized event.") }
        var messages: [[String: Any]] = []
        while let end = data.firstIndex(of: 10) {
            let line = data[..<end]
            data.removeSubrange(...end)
            if line.isEmpty { continue }
            guard let message = try JSONSerialization.jsonObject(with: line) as? [String: Any] else {
                throw ThumbnailError.message("Invalid Codex event.")
            }
            messages.append(message)
        }
        return messages
    }
}
