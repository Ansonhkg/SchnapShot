import XCTest
@testable import ThumbnailCore

final class MigrationTests: XCTestCase {
    func testStorageMovePreservesLoginAliasAndIsIdempotent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let old = root.appendingPathComponent(AppMigration.legacyName)
        try FileManager.default.createDirectory(at: old.appendingPathComponent("Codex"), withIntermediateDirectories: true)
        let result = try AppMigration.storage(in: root)
        XCTAssertEqual(result.storage.lastPathComponent, "SchnapShot")
        XCTAssertEqual(result.codexHome.path, old.appendingPathComponent("Codex").path)
        XCTAssertEqual(old.resolvingSymlinksInPath().path, result.storage.path)
        let again = try AppMigration.storage(in: root)
        XCTAssertEqual(again.storage, result.storage)
        XCTAssertEqual(again.codexHome, result.codexHome)
    }
    func testFreshInstallUsesNewStorageAndLoginHome() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let result = try AppMigration.storage(in: root)
        XCTAssertEqual(result.codexHome, result.storage.appendingPathComponent("Codex", isDirectory: true))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(AppMigration.legacyName).path))
    }
}
