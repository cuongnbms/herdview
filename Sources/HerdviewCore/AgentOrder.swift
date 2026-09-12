import Foundation

/// The order agents are listed in: the ones waiting on a human first, and
/// within one status the ones that changed most recently, so a row that just
/// moved is where the eye already is. Agents observed in the same snapshot
/// share a `since`, and fall back to their key so the list never reshuffles
/// on its own.
public enum AgentOrder {
    public static func before(_ a: TrackedAgent, _ b: TrackedAgent) -> Bool {
        let ra = a.status.attentionRank, rb = b.status.attentionRank
        if ra != rb { return ra < rb }
        if a.since != b.since { return a.since > b.since }
        return a.key < b.key
    }
}
