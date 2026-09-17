import Foundation
import Combine
import HerdviewCore

/// What the Quota card shows: one entry per Provider. Owned by the main actor;
/// the card observes it.
@MainActor
final class QuotaStore: ObservableObject {
    @Published private(set) var entries: [QuotaProvider: QuotaEntry] =
        Dictionary(uniqueKeysWithValues: QuotaProvider.allCases.map { ($0, .loading) })

    func entry(for provider: QuotaProvider) -> QuotaEntry {
        entries[provider] ?? .loading
    }

    func set(_ entry: QuotaEntry, for provider: QuotaProvider) {
        entries[provider] = entry
    }
}
