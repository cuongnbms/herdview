import Foundation

/// Which sessions a host runner must start watching and which to stop.
public struct SessionDiff: Equatable, Sendable {
    public let start: [HerdrSession]
    public let stop: [String]

    public init(start: [HerdrSession], stop: [String]) {
        self.start = start
        self.stop = stop
    }

    public static func compute(watching: Set<String>, discovered: [HerdrSession]) -> SessionDiff {
        let running = discovered.filter(\.running)
        let runningNames = Set(running.map(\.name))
        let start = running.filter { !watching.contains($0.name) }
        let stop = watching.filter { !runningNames.contains($0) }.sorted()
        return SessionDiff(start: start, stop: stop)
    }
}
