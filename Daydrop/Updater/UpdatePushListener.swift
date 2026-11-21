import Foundation

/// Ultra-lightweight SSE (Server-Sent Events) push listener using ntfy.sh.
/// Receives real-time release wake-up signals (< 2s latency) and triggers the official
/// GitHub Releases verifier in `AppUpdater` (never trusts download URLs from push messages).
public final class UpdatePushListener: @unchecked Sendable {
    public static let topic = "daydrop-iwtem-releases-7f3a9c2e"
    public static var sseEndpoint: URL {
        URL(string: "https://ntfy.sh/\(topic)/sse")!
    }

    private struct NtfyEvent: Decodable {
        let event: String
        let message: String?
    }

    private let onSignal: @Sendable (String?) -> Void
    private var listenTask: Task<Void, Never>?
    private let lock = NSLock()
    private var lastSignalDate: Date = .distantPast

    public init(onSignal: @escaping @Sendable (String?) -> Void) {
        self.onSignal = onSignal
    }

    deinit {
        stop()
    }

    /// Parses an SSE `data: {...}` line from ntfy.sh and returns the message payload if `event == "message"`.
    public static func parseSSEDataLine(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }
        let jsonPart = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard let data = jsonPart.data(using: .utf8),
              let payload = try? JSONDecoder().decode(NtfyEvent.self, from: data),
              payload.event == "message" else {
            return nil
        }
        return payload.message?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func start() {
        lock.lock()
        guard listenTask == nil else {
            lock.unlock()
            return
        }
        listenTask = Task.detached(priority: .utility) { [weak self] in
            await self?.runReconnectLoop()
        }
        lock.unlock()
    }

    public func stop() {
        lock.lock()
        listenTask?.cancel()
        listenTask = nil
        lock.unlock()
    }

    public func restart() {
        stop()
        start()
    }

    private func runReconnectLoop() async {
        var backoffSeconds: UInt64 = 5

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 300   // Long-lived SSE stream (ntfy sends keepalive every ~45s)
        config.timeoutIntervalForResource = 0    // Infinite stream lifetime
        config.waitsForConnectivity = true
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }

        while !Task.isCancelled {
            var request = URLRequest(url: Self.sseEndpoint)
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("Daydrop-SSE", forHTTPHeaderField: "User-Agent")

            do {
                let (bytes, response) = try await session.bytes(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    try await Task.sleep(nanoseconds: backoffSeconds * 1_000_000_000)
                    backoffSeconds = min(60, backoffSeconds * 2)
                    continue
                }

                // Connected cleanly — reset backoff
                backoffSeconds = 5

                for try await line in bytes.lines {
                    if Task.isCancelled { break }
                    if let message = Self.parseSSEDataLine(line) {
                        handleSignalDebounced(message)
                    }
                }
            } catch {
                if Task.isCancelled { break }
            }

            if Task.isCancelled { break }
            try? await Task.sleep(nanoseconds: backoffSeconds * 1_000_000_000)
            backoffSeconds = min(60, backoffSeconds * 2)
        }
    }

    private func handleSignalDebounced(_ message: String) {
        lock.lock()
        let now = Date()
        let shouldFire = now.timeIntervalSince(lastSignalDate) >= 8.0
        if shouldFire {
            lastSignalDate = now
        }
        lock.unlock()

        if shouldFire {
            onSignal(message)
        }
    }
}
