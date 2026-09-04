import Foundation

@MainActor
public final class CodexConnection {
    public var onNotification: ((String, [String: Any]) -> Void)?
    public var onDisconnect: ((Error) -> Void)?
    public private(set) var running = false
    public let home: URL
    private let binaryOverride: URL?
    private var process: Process?
    private var input: FileHandle?
    private var parser = JSONLineBuffer()
    private var nextID = 0
    private var pending: [Int: CheckedContinuation<[String: Any], Error>] = [:]
    private var timeouts: [Int: Task<Void, Never>] = [:]
    private var connectionID = UUID()
    private var reader: Task<Void, Never>?

    public init(home: URL, binaryOverride: URL? = nil) { self.home = home; self.binaryOverride = binaryOverride }

    public static func executable() -> URL? {
        let fm = FileManager.default
        let custom = ProcessInfo.processInfo.environment["CMDSHIFT4_CODEX_BIN"]
        let candidates = [custom, "/opt/homebrew/bin/codex", "/usr/local/bin/codex",
            fm.homeDirectoryForCurrentUser.appendingPathComponent(".bun/bin/codex").path,
            "/Applications/Codex.app/Contents/Resources/codex"].compactMap { $0 }
        return candidates.first(where: { fm.isExecutableFile(atPath: $0) }).map(URL.init(fileURLWithPath:))
    }

    public func start() async throws {
        if running { return }
        guard let binary = binaryOverride ?? Self.executable() else {
            throw ThumbnailError.message("Codex is not installed. Install the Codex app or CLI, then click Retry connection.")
        }
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let p = Process(), stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        p.executableURL = binary
        p.arguments = ["app-server", "--stdio", "-c", "features.image_generation=true",
            "-c", "features.shell_tool=false", "-c", "features.multi_agent=false",
            "-c", "features.apps=false", "-c", "features.plugins=false",
            "-c", "features.hooks=false", "-c", "features.browser_use=false",
            "-c", "features.computer_use=false", "-c", "web_search=\"disabled\"",
            "-c", "project_doc_max_bytes=0", "-c", "skills.include_instructions=false",
            "-c", "cli_auth_credentials_store=\"keyring\""]
        var environment = ProcessInfo.processInfo.environment
        environment["CODEX_HOME"] = home.path
        // Never let an inherited API key silently change the billing/auth mode.
        environment.removeValue(forKey: "OPENAI_API_KEY")
        environment.removeValue(forKey: "CODEX_API_KEY")
        p.environment = environment
        p.currentDirectoryURL = home
        p.standardInput = stdin; p.standardOutput = stdout; p.standardError = stderr
        let id = UUID(); connectionID = id
        p.terminationHandler = { [weak self] process in
            Task { @MainActor in
                guard let self, self.connectionID == id else { return }
                let error = ThumbnailError.message("Codex disconnected (exit \(process.terminationStatus)). Retry the connection.")
                self.failAll(error); self.onDisconnect?(error)
            }
        }
        try p.run()
        process = p; input = stdin.fileHandleForWriting; running = true; parser = JSONLineBuffer()
        let chunks = AsyncStream<Data> { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                while true {
                    let data = stdout.fileHandleForReading.availableData
                    if data.isEmpty { break }
                    continuation.yield(data)
                }
                continuation.finish()
            }
        }
        reader = Task { [weak self] in
            for await data in chunks {
                guard let self, !Task.isCancelled, self.connectionID == id else { return }
                do { for message in try self.parser.append(data) { self.receive(message) } }
                catch { self.stop(); self.onDisconnect?(error); return }
            }
        }
        // Drain stderr, but never persist auth URLs, tokens, or screenshot content in logs.
        DispatchQueue.global(qos: .utility).async {
            while !stderr.fileHandleForReading.availableData.isEmpty {}
        }
        do {
            _ = try await request("initialize", ["clientInfo": ["name": "SchnapShot", "title": "SchnapShot", "version": "0.1.0"], "capabilities": ["experimentalApi": true]])
            try send(["method": "initialized", "params": [:]])
        } catch { stop(); throw error }
    }

    public func request(_ method: String, _ params: [String: Any] = [:], timeout: UInt64 = 30) async throws -> [String: Any] {
        guard running else { throw ThumbnailError.message("Codex is not connected.") }
        nextID += 1; let id = nextID
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            timeouts[id] = Task { [weak self] in
                try? await Task.sleep(nanoseconds: timeout * 1_000_000_000)
                guard !Task.isCancelled, let self else { return }
                self.pending.removeValue(forKey: id)?.resume(throwing: ThumbnailError.message("Codex took too long to respond to \(method). Try again."))
                self.timeouts.removeValue(forKey: id)
            }
            do { try send(["id": id, "method": method, "params": params]) }
            catch { timeouts.removeValue(forKey: id)?.cancel(); pending.removeValue(forKey: id)?.resume(throwing: error) }
        }
    }

    private func send(_ value: [String: Any]) throws {
        var data = try JSONSerialization.data(withJSONObject: value); data.append(10)
        guard let input else { throw ThumbnailError.message("Codex input is closed.") }
        try input.write(contentsOf: data)
    }

    private func receive(_ value: [String: Any]) {
        if let id = value["id"] as? Int, let continuation = pending.removeValue(forKey: id) {
            timeouts.removeValue(forKey: id)?.cancel()
            if let error = value["error"] as? [String: Any] {
                continuation.resume(throwing: ThumbnailError.message(error["message"] as? String ?? "Codex request failed."))
            } else { continuation.resume(returning: value["result"] as? [String: Any] ?? [:]) }
            return
        }
        if let id = value["id"], value["method"] != nil {
            // This app never approves commands, extra permissions, or unknown server tool requests.
            try? send(["id": id, "error": ["code": -32601, "message": "SchnapShot only permits image generation."]])
            return
        }
        if let method = value["method"] as? String { onNotification?(method, value["params"] as? [String: Any] ?? [:]) }
    }

    private func failAll(_ error: Error) {
        running = false
        for task in timeouts.values { task.cancel() }; timeouts.removeAll()
        let callbacks = pending.values; pending.removeAll()
        for continuation in callbacks { continuation.resume(throwing: error) }
    }
    public func stop() {
        connectionID = UUID()
        reader?.cancel(); reader = nil
        process?.terminationHandler = nil
        try? input?.close(); input = nil
        if process?.isRunning == true { process?.terminate() }
        process = nil
        failAll(CancellationError())
    }
}
