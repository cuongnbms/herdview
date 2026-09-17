import Foundation
import HerdviewCore

/// Fetches every Provider's Quota while the window is visible.
///
/// Each Provider is fetched on its own, so a slow or failing one never holds up
/// another's row. When to fetch is `QuotaSchedule`'s decision; what a response
/// means is `QuotaOutcome`'s; this class only does the reading and the waiting.
///
/// Lifecycle is owned here: `start()` runs exactly one tick loop and `stop()`
/// cancels that loop and every fetch it started. Work started before `stop()`
/// checks for cancellation before it logs or writes, so a read or request that
/// lands late leaves no trace.
@MainActor
final class QuotaMonitor {
    /// How often the loop wakes to ask the schedule. Well under the poll
    /// interval, so a fetch is at most this late.
    private static let tickNanos: UInt64 = 30 * 1_000_000_000

    private let store: QuotaStore
    private let isWindowVisible: () -> Bool
    private let session: URLSession
    /// Non-nil exactly while the monitor is running. It is the single source of
    /// truth for `start()`/`stop()`, so a second `start()` cannot spawn a loop
    /// that `stop()` has no handle to cancel.
    private var loop: Task<Void, Never>?
    /// Every fetch in flight, so `stop()` can cancel them all. A Provider is
    /// fetched only while it has no entry here.
    private var fetches: [QuotaProvider: Task<Void, Never>] = [:]
    /// Which fetch is current for a Provider. Cleanup is only allowed for the
    /// id it registered, so a cancelled fetch that unwinds late cannot unmark
    /// the fetch that replaced it.
    private var fetchIDs: [QuotaProvider: UUID] = [:]
    private var lastStarted: [QuotaProvider: Date] = [:]
    private var rateLimitedUntil: [QuotaProvider: Date] = [:]

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

    /// Idempotent: while a loop is running this does nothing, so no call can
    /// leave an earlier loop untracked and polling after `stop()`.
    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.refresh(.tick)
                do {
                    try await Task.sleep(nanoseconds: QuotaMonitor.tickNanos)
                } catch {
                    return  // Cancelled: `stop()` is unwinding this loop.
                }
            }
        }
    }

    /// Cancels the tick loop and every fetch it started. Cancellation is
    /// checked before any log or store write, so nothing that was in flight
    /// can surface after the window is gone.
    func stop() {
        loop?.cancel()
        loop = nil
        for fetch in fetches.values { fetch.cancel() }
        fetches.removeAll()
        fetchIDs.removeAll()
    }

    /// The window has just been shown. A stopped monitor stays stopped until
    /// `start()`: this only refreshes work the running loop owns, so it cannot
    /// quietly undo `stop()` with a store write of its own.
    func windowShown() {
        refresh(.shown)
    }

    private func refresh(_ trigger: QuotaSchedule.Trigger) {
        guard loop != nil, isWindowVisible() else { return }
        let now = Date()
        for provider in QuotaProvider.allCases where fetches[provider] == nil {
            guard QuotaSchedule.isDue(trigger, lastStarted: lastStarted[provider],
                                      rateLimitedUntil: rateLimitedUntil[provider], now: now) else { continue }
            lastStarted[provider] = now
            let id = UUID()
            fetchIDs[provider] = id
            fetches[provider] = Task { [weak self] in
                defer { self?.endFetch(provider, id: id) }
                await self?.fetch(provider)
            }
        }
    }

    /// Clears a finished fetch, but only if it is still the one tracking this
    /// Provider: a cancelled fetch that unwinds after its replacement must not
    /// erase the replacement's tracking.
    private func endFetch(_ provider: QuotaProvider, id: UUID) {
        guard fetchIDs[provider] == id else { return }
        fetchIDs[provider] = nil
        fetches[provider] = nil
    }

    private func fetch(_ provider: QuotaProvider) async {
        let lookup = await CredentialReader.read(provider)
        // A cancelled fetch leaves no trace: `stop()` means the window is gone,
        // so a read that lands late must not log, back off or write. Nothing
        // suspends between here and the store write, so `stop()` cannot land
        // between them.
        guard !Task.isCancelled else { return }

        let outcome: QuotaOutcome
        switch lookup {
        case .notSignedIn:
            store.set(.notSignedIn, for: provider)
            return
        case .failed(let reason):
            outcome = .failed(reason)
        case .found(let credential):
            // `nil` means the request was cancelled, not that it failed.
            guard let result = await request(provider, credential) else { return }
            outcome = result
        }

        guard !Task.isCancelled else { return }
        if case .rateLimited(let until) = outcome {
            rateLimitedUntil[provider] = until
        }
        NSLog("herdview: quota %@: %@", provider.rawValue, outcome.logDescription)
        store.set(store.entry(for: provider).applying(outcome, provider: provider, now: Date()), for: provider)
    }

    /// `nil` when the request was cancelled. Cancellation is the lifecycle, not
    /// a Provider failure, so it must not become a `"network error"` outcome.
    private func request(_ provider: QuotaProvider, _ credential: QuotaCredential) async -> QuotaOutcome? {
        let request = QuotaRequests.request(for: provider, credential: credential)
        do {
            let (data, response) = try await session.data(for: request)
            guard !Task.isCancelled else { return nil }
            guard let http = response as? HTTPURLResponse else { return .failed("no HTTP response") }
            return QuotaOutcome.classify(provider: provider, status: http.statusCode, body: data,
                                         retryAfter: http.value(forHTTPHeaderField: "Retry-After"), now: Date())
        } catch is CancellationError {
            return nil
        } catch let error as URLError where error.code == .cancelled {
            return nil
        } catch let error as URLError where error.code == .timedOut {
            return .failed("timed out")
        } catch {
            return .failed("network error")
        }
    }
}
