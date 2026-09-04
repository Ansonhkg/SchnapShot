import XCTest
@testable import ThumbnailCore

final class ConnectionTests: XCTestCase {
    @MainActor
    private func fixture() throws -> (CodexConnection, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("SchnapShot-rpc-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let script = dir.appendingPathComponent("fake-codex")
        let resource = try XCTUnwrap(Bundle.module.url(forResource: "fake-codex", withExtension: "py", subdirectory: "Fixtures"))
        try FileManager.default.copyItem(at: resource, to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        return (CodexConnection(home: dir.appendingPathComponent("home"), binaryOverride: script), dir)
    }

    @MainActor
    func testHandshakeAndOrderedGenerationEvents() async throws {
        let (connection, dir) = try fixture()
        defer { connection.stop(); try? FileManager.default.removeItem(at: dir) }
        try await connection.start()
        let account = try await connection.request("account/read")
        XCTAssertEqual(account["requiresOpenaiAuth"] as? Bool, true)
        let done = expectation(description: "generation finished")
        var methods: [String] = []
        connection.onNotification = { method, params in
            methods.append(method)
            XCTAssertEqual(params["threadId"] as? String, "fixture-thread")
            if method == "turn/completed" { done.fulfill() }
        }
        _ = try await connection.request("test/events")
        await fulfillment(of: [done], timeout: 3)
        XCTAssertEqual(methods, ["item/completed", "turn/completed"])
    }

    @MainActor
    func testServerErrorIsSurfaced() async throws {
        let (connection, dir) = try fixture()
        defer { connection.stop(); try? FileManager.default.removeItem(at: dir) }
        try await connection.start()
        do { _ = try await connection.request("test/error"); XCTFail("Expected failure") }
        catch { XCTAssertEqual(error.localizedDescription, "Fixture failure") }
    }

    @MainActor
    func testTimeoutAndRecovery() async throws {
        let (connection, dir) = try fixture()
        defer { connection.stop(); try? FileManager.default.removeItem(at: dir) }
        try await connection.start()
        do { _ = try await connection.request("test/timeout", timeout: 1); XCTFail("Expected timeout") }
        catch { XCTAssertTrue(error.localizedDescription.contains("too long")) }
        let result = try await connection.request("account/read")
        XCTAssertNotNil(result["requiresOpenaiAuth"])
    }

    @MainActor
    func testProcessExitFailsPendingRequests() async throws {
        let (connection, dir) = try fixture()
        defer { connection.stop(); try? FileManager.default.removeItem(at: dir) }
        try await connection.start()
        do { _ = try await connection.request("test/exit"); XCTFail("Expected disconnection") }
        catch { XCTAssertTrue(error.localizedDescription.contains("disconnected")) }
        XCTAssertFalse(connection.running)
    }

    @MainActor
    func testStopCancelsPendingRequestsAndCanRestart() async throws {
        let (connection, dir) = try fixture()
        defer { connection.stop(); try? FileManager.default.removeItem(at: dir) }
        try await connection.start()
        let waiting = Task { try await connection.request("test/timeout") }
        await Task.yield()
        connection.stop()
        do { _ = try await waiting.value; XCTFail("Expected cancellation") } catch {}
        try await connection.start()
        let result = try await connection.request("account/read")
        XCTAssertNotNil(result["requiresOpenaiAuth"])
    }
}
