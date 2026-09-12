import SwiftUI
import HerdPetCore

/// What every host is running: a summary of the whole herd, then one section
/// per host, most attention-worthy agent first. This is the window's whole
/// content. The tick lives here, since the elapsed timers and the blink are
/// the only things that move on their own; it runs at the blink's half-beat,
/// which is the faster of the two.
struct AgentListView: View {
    @ObservedObject var store: AgentStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: BlinkPhase.halfPeriod)) { context in
            VStack(spacing: 0) {
                SummaryBar(agents: store.agents)
                    .background(Color(nsColor: .windowBackgroundColor))
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        if let error = store.configError {
                            Notice(symbol: "exclamationmark.triangle.fill", text: error, tint: .red)
                                .padding(.horizontal, Metrics.gutter)
                                .padding(.top, 12)
                        }
                        if store.hostOrder.isEmpty {
                            Notice(symbol: "server.rack",
                                   text: "No hosts yet. Add one in \(ConfigLoader.defaultPath)")
                                .padding(.horizontal, Metrics.gutter)
                                .padding(.top, 12)
                        }
                        ForEach(store.hostOrder, id: \.self) { host in
                            HostSection(host: host, store: store, now: context.date)
                        }
                    }
                    .padding(.bottom, 10)
                }
            }
            // The list gets the lighter content surface and the summary bar
            // keeps the window's own grey, the way Finder and Mail separate a
            // toolbar from what it is describing. Both are stated outright: a
            // hosting view inherits no background, so leaving either implicit
            // puts white text on a white sheet in dark mode.
            .background(Color(nsColor: .textBackgroundColor))
            // The popover was a fixed 360 wide; a window is whatever the user
            // drags it to, so the list fills the width and the rows spread.
            .frame(minWidth: 360, maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

private enum Metrics {
    /// Page margin. Rows carry their own inset on top of this, so a row's
    /// title lines up a fixed distance in from the host name above it.
    static let gutter: CGFloat = 12
    static let rowInset: CGFloat = 8
}

// MARK: - Summary

/// The herd at a glance. Blocked is the only count that gets a filled chip:
/// a done agent is also waiting on you, but only a blocked one is waiting
/// before it can carry on. Everything else is stated quietly, and when the
/// herd is healthy this bar is meant to look uneventful.
private struct SummaryBar: View {
    let agents: [TrackedAgent]

    var body: some View {
        let blocked = agents.filter { $0.status == .blocked }.count
        HStack(spacing: 10) {
            if blocked > 0 {
                Chip(count: blocked, label: "blocked", status: .blocked, filled: true)
            } else if agents.isEmpty {
                Text("Nothing running")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Text("Nothing blocked")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            ForEach(Self.quietOrder, id: \.self) { status in
                let count = agents.filter { $0.status == status }.count
                if count > 0 {
                    Chip(count: count, label: status.rawValue, status: status, filled: false)
                }
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 9)
    }

    /// Idle and unknown agents are left out on purpose: idle is the absence of
    /// work, not a kind of work, and a bar that counts everything stops
    /// answering the only question it is here for.
    private static let quietOrder: [AgentStatus] = [.working, .done]
}

private struct Chip: View {
    let count: Int
    let label: String
    let status: AgentStatus
    let filled: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(status.tint)
                .frame(width: 7, height: 7)
            Text("\(count) \(label)")
                .font(.system(size: 12, weight: filled ? .semibold : .regular))
                .foregroundStyle(filled ? Color.primary : Color.secondary)
        }
        .padding(.horizontal, filled ? 9 : 0)
        .padding(.vertical, filled ? 4 : 0)
        .background(
            Capsule().fill(status.tint.opacity(filled ? 0.18 : 0))
        )
    }
}

// MARK: - Host

private struct HostSection: View {
    let host: String
    @ObservedObject var store: AgentStore
    let now: Date

    var body: some View {
        let agents = store.agents(forHost: host)
        let unreachable = store.unreachableHosts.contains(host)
        Section {
            if agents.isEmpty {
                Notice(symbol: unreachable ? "antenna.radiowaves.left.and.right.slash" : "moon.zzz",
                       text: unreachable ? "Can't reach this host" : "No agents here",
                       tint: unreachable ? Color(nsColor: .systemOrange) : nil)
                    .padding(.horizontal, Metrics.gutter + Metrics.rowInset)
                    .padding(.vertical, 6)
            }
            ForEach(agents, id: \.key) { agent in
                AgentRow(agent: agent, now: now)
                    .padding(.horizontal, Metrics.gutter)
            }
        } header: {
            HostHeader(host: host, count: agents.count, unreachable: unreachable)
        }
    }
}

/// Host names are set off by a hairline that runs to the trailing edge and
/// carries the agent count at its end — the rule is doing the separating, so
/// the name itself needs no tracked-out caps to announce it.
private struct HostHeader: View {
    let host: String
    let count: Int
    let unreachable: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(host)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            if unreachable {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(nsColor: .systemOrange))
                        .frame(width: 6, height: 6)
                    Text("unreachable")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(height: 1)
            Text("\(count)")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Metrics.gutter + Metrics.rowInset)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Agent

private struct AgentRow: View {
    let agent: TrackedAgent
    let now: Date

    var body: some View {
        let text = AgentTitles.rowText(for: agent)
        HStack(spacing: 10) {
            icon
            VStack(alignment: .leading, spacing: 1) {
                Text(text.primary)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(text.secondary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            StatusPill(status: agent.status)
            Text(TimerFormatter.string(from: agent.since, to: now))
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(agent.status == .blocked ? .primary : .secondary)
                .frame(minWidth: 48, alignment: .trailing)
        }
        .padding(.horizontal, Metrics.rowInset)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(rowFill)
        )
        // Keyed on the beat, not on `now`: the fill is meant to ease between
        // the two ends of the blink, and a row whose only moving part is a
        // clock should not animate anything at all.
        .animation(.easeInOut(duration: 0.4), value: isBright)
        .help(tooltip(for: text))
    }

    /// A blocked or done row blinks for as long as it stays that way — it is
    /// asking for a person, and it keeps asking until someone comes. Every
    /// other row is plain. Rows do not light up under the pointer, because
    /// clicking one does nothing and a hover highlight would promise that it
    /// did.
    private var rowFill: Color {
        agent.status.tint.opacity(agent.status.rowFillOpacity(bright: isBright))
    }

    private var isBright: Bool { BlinkPhase.isBright(at: now) }

    @ViewBuilder private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.06))
            if let image = AgentIcons.image(for: AgentKind.from(label: agent.info.agent)) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
            } else {
                Image(systemName: "terminal")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 24, height: 24)
    }

    /// Both lines are truncated in the row, so the pointer can ask for the
    /// parts that did not fit — the directory spelled out in full, since that
    /// is the one the row shortens to its last component.
    private func tooltip(for text: AgentRowText) -> String {
        guard let cwd = agent.info.cwd, !cwd.isEmpty else {
            return "\(text.primary)\n\(text.secondary)"
        }
        return "\(cwd)\n\(text.secondary)"
    }
}

private struct StatusPill: View {
    let status: AgentStatus

    var body: some View {
        Text(status.rawValue)
            .font(.system(size: 11, weight: status == .blocked ? .semibold : .regular))
            .foregroundStyle(status == .blocked ? Color.primary : Color.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 2.5)
            .background(
                Capsule().fill(status.tint.opacity(status == .blocked ? 0.24 : 0.14))
            )
    }
}

// MARK: - Empty and error states

/// Every state where there is nothing to list says what is true and, where
/// there is one, what to do about it.
private struct Notice: View {
    let symbol: String
    let text: String
    var tint: Color? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(tint ?? Color.secondary)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(tint == nil ? Color.secondary : Color.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
