import XCTest
import AppKit
import ImageIO
@testable import ThumbnailCore

final class ThumbnailCoreTests: XCTestCase {
    func testSizeValidation() {
        XCTAssertTrue(OutputSize.social.isValid)
        for (_, size) in OutputSize.presets { XCTAssertTrue(size.isValid) }
        XCTAssertFalse(OutputSize(width: 0, height: 630).isValid)
        XCTAssertFalse(OutputSize(width: -1, height: 630).isValid)
        XCTAssertFalse(OutputSize(width: Int.max, height: Int.max).isValid)
        XCTAssertFalse(OutputSize(width: 4096, height: 4096).isValid)
        XCTAssertFalse(OutputSize(width: 64, height: 4096).isValid)
        XCTAssertEqual(OutputSize.social.prompt, "Create a thumbnail from this image, 1200x630.")
    }

    func testJSONLinesSurviveChunksAndUnicode() throws {
        var buffer = JSONLineBuffer()
        let input = Data("{\"id\":1,\"result\":{\"text\":\"Hello × 世界\"}}\n{\"method\":\"ready\"}\n".utf8)
        var result: [[String: Any]] = []
        for byte in input { result += try buffer.append(Data([byte])) }
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual((result[0]["result"] as? [String: Any])?["text"] as? String, "Hello × 世界")
        XCTAssertEqual(result[1]["method"] as? String, "ready")
    }

    func testMalformedEventFails() {
        var buffer = JSONLineBuffer()
        XCTAssertThrowsError(try buffer.append(Data("not-json\n".utf8)))
    }

    private func fixture() throws -> Data {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 320, pixelsHigh: 160,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let blue = NSColor(deviceRed: 0.1, green: 0.4, blue: 0.9, alpha: 1)
        for y in 0..<160 { for x in 0..<320 { bitmap.setColor(blue, atX: x, y: y) } }
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }

    func testExactOutputDimensionsForAllPresets() throws {
        let source = try fixture()
        for (_, size) in OutputSize.presets {
            let data = try ImageOutput.png(from: source, size: size)
            let imageSource = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))
            XCTAssertEqual(image.width, size.width); XCTAssertEqual(image.height, size.height)
        }
    }

    func testRejectsCorruptImage() {
        XCTAssertThrowsError(try ImageOutput.png(from: Data("not an image".utf8), size: .social))
    }

    func testGenerationItemRequiresCompletedImage() throws {
        let root = FileManager.default.temporaryDirectory
        XCTAssertNil(try ImageOutput.generatedData(item: ["type": "agentMessage", "status": "completed"], allowedRoot: root))
        XCTAssertNil(try ImageOutput.generatedData(item: ["type": "imageGeneration", "status": "in_progress"], allowedRoot: root))
        let source = try fixture()
        let decoded = try ImageOutput.generatedData(item: ["type": "imageGeneration", "status": "completed", "result": source.base64EncodedString()], allowedRoot: root)
        XCTAssertEqual(decoded, source)
    }

    func testReturnedPathCannotEscapeStorage() {
        XCTAssertThrowsError(try ImageOutput.generatedData(item: ["type": "imageGeneration", "status": "completed", "savedPath": "/etc/passwd"], allowedRoot: URL(fileURLWithPath: "/tmp/SchnapShot-test")))
    }

    func testSavedImagePath() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("SchnapShot-test-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let data = try fixture(), file = dir.appendingPathComponent("generated.png")
        try data.write(to: file)
        XCTAssertEqual(try ImageOutput.generatedData(item: ["type": "imageGeneration", "status": "completed", "savedPath": file.path], allowedRoot: dir), data)
    }

    @MainActor
    func testDisconnectedRPCFailsImmediately() async {
        let connection = CodexConnection(home: URL(fileURLWithPath: "/tmp/not-started-SchnapShot"))
        do { _ = try await connection.request("account/read"); XCTFail("Must not send on a closed connection") }
        catch { XCTAssertTrue(error.localizedDescription.contains("not connected")) }
    }

    @MainActor
    func testInstalledCodexHandshakeWhenRequested() async throws {
        guard ProcessInfo.processInfo.environment["CMDSHIFT4_LIVE_CHECK"] == "1" else { throw XCTSkip("Opt-in local Codex handshake") }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("SchnapShot-handshake-\(UUID())")
        let connection = CodexConnection(home: dir)
        defer { connection.stop(); try? FileManager.default.removeItem(at: dir) }
        try await connection.start()
        let response = try await connection.request("account/read")
        XCTAssertNotNil(response["requiresOpenaiAuth"])
        let capabilities = try await connection.request("modelProvider/capabilities/read")
        XCTAssertEqual(capabilities["imageGeneration"] as? Bool, true)
    }
}
