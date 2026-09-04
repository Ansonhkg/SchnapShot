import AppKit
import ImageIO
import UniformTypeIdentifiers

public enum ImageOutput {
    /// Preserve the generated composition, adding a neutral matte only if its ratio differs.
    public static func png(from data: Data, size: OutputSize) throws -> Data {
        guard size.isValid else { throw ThumbnailError.message("Invalid output dimensions.") }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width > 0, image.height > 0,
              let context = CGContext(data: nil, width: size.width, height: size.height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw ThumbnailError.message("Codex returned an unreadable image.") }
        context.setFillColor(CGColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let scale = min(Double(size.width) / Double(image.width), Double(size.height) / Double(image.height))
        let w = Double(image.width) * scale, h = Double(image.height) * scale
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: (Double(size.width) - w) / 2,
                                      y: (Double(size.height) - h) / 2, width: w, height: h))
        guard let rendered = context.makeImage() else { throw ThumbnailError.message("Could not render the thumbnail.") }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)
        else { throw ThumbnailError.message("Could not encode the thumbnail.") }
        CGImageDestinationAddImage(destination, rendered, nil)
        guard CGImageDestinationFinalize(destination) else { throw ThumbnailError.message("Could not finish the PNG.") }
        return output as Data
    }

    public static func generatedData(item: [String: Any], allowedRoot: URL) throws -> Data? {
        guard item["type"] as? String == "imageGeneration", item["status"] as? String == "completed" else { return nil }
        if let path = item["savedPath"] as? String {
            let url = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
            let root = allowedRoot.resolvingSymlinksInPath().standardizedFileURL.path + "/"
            guard url.path.hasPrefix(root) else { throw ThumbnailError.message("Codex returned an image outside its app storage.") }
            let bytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard bytes <= 50 * 1024 * 1024 else { throw ThumbnailError.message("Generated image exceeds the 50 MB limit.") }
            return try Data(contentsOf: url)
        }
        if let result = item["result"] as? String, !result.isEmpty, result.utf8.count <= 70_000_000 {
            let payload = result.hasPrefix("data:") ? String(result.split(separator: ",", maxSplits: 1).last ?? "") : result
            return Data(base64Encoded: payload)
        }
        return nil
    }
}
