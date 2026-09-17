import Foundation
import HerdviewCore

/// Fetches every Provider's Quota while the window is visible.
///
/// Each Provider is fetched on its own, so a slow or failing one never holds up
/// another's row. When to fetch is `QuotaSchedule`'s decision; what a response
/// means is `QuotaOutcome`'s; this class only does the reading and the waiting.
@MainActor
final class QuotaMonitor {
    /// How often the loop wakes to ask the schedule. Well under the poll
    /// interval, so a fetch is at most this late.
    private static let tickNanos: UInt64 = 30 * 1_000_000_000

    private let store: QuotaStore
    private let isWindowVisible: () -> Bool
    private let session: URLSession
    private var loop: Task<Void, Never>?
    private var lastStarted: [QuotaProvider: Date] = [:]
    private var rateLimitedUntil: [QuotaProvider: Date] = [:]
    private var inFlight: Set<QuotaProvider> = []

    init(store: QuotaStore, isWindowVisible: @escaping () -> Bool) {
        self.store = store
        self.isWindowVisible = isWindowVisible
        // No cache and no cookies: every answer is fresh, and nothing a
        // Provider sets is kept between fetches.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        session = URLSession(configuration: configuration)
    }

    func start() {
        loop = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh(.tick)
                try? await Task.sleep(nanoseconds: QuotaMonitor.tickNanos)
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    /// The window has just been shown.
    func windowShown() {
        refresh(.shown)
    }

    private func refresh(_ trigger: QuotaSchedule.Trigger) {
        guard isWindowVisible() else { return }
        let now = Date()
        for provider in QuotaProvider.allCases where !inFlight.contains(provider) {
            guard QuotaSchedule.isDue(trigger, lastStarted: lastStarted[provider],
                                      rateLimitedUntil: rateLimitedUntil[provider], now: now) else { continue }
            lastStarted[provider] = now
            inFlight.insert(provider)
            Task { [weak self] in
                await self?.fetch(provider)
                self?.inFlight.remove(provider)
            }
        }
    }

    private func fetch(_ provider: QuotaProvider) async {
        let outcome: QuotaOutcome
        switch await CredentialReader.read(provider) {
        case .notSignedIn:
            store.set(.notSignedIn, for: provider)
            return
        case .failed(let reason):
            outcome = .failed(reason)
        case .found(let credential):
            outcome = await request(provider, credential)
        }
        if case .rateLimited(let until) = outcome {
            rateLimitedUntil[provider] = until
        }
        NSLog("herdview: quota %@: %@", provider.rawValue, outcome.logDescription)
        store.set(store.entry(for: provider).applying(outcome, provider: provider, now: Date()), for: provider)
    }

    private func request(_ provider: QuotaProvider, _ credential: QuotaCredential) async -> QuotaOutcome {
        let request = QuotaRequests.request(for: provider, credential: credential)
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failed("no HTTP response") }
            return QuotaOutcome.classify(provider: provider, status: http.statusCode, body: data,
                                         retryAfter: http.value(forHTTPHeaderField: "Retry-After"), now: Date())
        } catch let error as URLError where error.code == .timedOut {
            return .failed("timed out")
        } catch {
            return .failed("network error")
        }
    }
}
