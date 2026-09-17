import Foundation
import Combine
import HerdviewCore

/// What the Quota card shows: one entry per Provider. Owned by the main actor;
/// the card observes it.
@MainActor
final class QuotaStore: ObservableObject {
    @Published private(set) var entries: [QuotaProvider: QuotaEntry] =
        Dictionary(uniqueKeysWithValues: QuotaProvider.allCases.map { ($0, .loading) })

    /// Providers with a fetch in flight, so the card can show that a refresh
    /// is under way.
    @Published private(set) var fetching: Set<QuotaProvider> = []

    /// Whether the card is folded down to one line. Remembered across
    /// launches.
    @Published var isCollapsed: Bool {
        didSet { preferences.isQuotaCollapsed = isCollapsed }
    }

    private let preferences: WindowPreferences

    init(preferences: WindowPreferences = WindowPreferences()) {
        self.preferences = preferences
        isCollapsed = preferences.isQuotaCollapsed
    }

    /// What the card's refresh button runs. Set by whoever owns the monitor,
    /// so the card never holds the monitor itself.
    var refreshAction: (() -> Void)?

    func refreshNow() {
        refreshAction?()
    }

    func entry(for provider: QuotaProvider) -> QuotaEntry {
        entries[provider] ?? .loading
    }

    func set(_ entry: QuotaEntry, for provider: QuotaProvider) {
        entries[provider] = entry
    }

    func setFetching(_ isFetching: Bool, for provider: QuotaProvider) {
        if isFetching { fetching.insert(provider) } else { fetching.remove(provider) }
    }
}
