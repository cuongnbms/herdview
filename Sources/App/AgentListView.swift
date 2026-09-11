import SwiftUI
import HerdPetCore

/// What every host is running: one section per host, most attention-worthy
/// agent first. This is the window's whole content. The one-second tick lives
/// here, since the elapsed timers are the only thing that moves on its own.
struct AgentListView: View {
    @ObservedObject var store: AgentStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 10) {
                if let error = store.configError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if store.hostOrder.isEmpty {
                    Text("No hosts configured.\nEdit \(ConfigLoader.defaultPath)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(store.hostOrder, id: \.self) { host in
                    HostSection(host: host, store: store, now: context.date)
                }
            }
            .padding(12)
            // The popover was a fixed 360 wide; a window is whatever the user
            // drags it to, so the list fills the width and the rows spread.
            .frame(minWidth: 360, maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

private struct HostSection: View {
    let host: String
    @ObservedObject var store: AgentStore
    let now: Date

    var body: some View {
        let agents = store.agents(forHost: host)
        let unreachable = store.unreachableHosts.contains(host)
        let names = AgentTitles.displayNames(for: agents)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(host).font(.headline)
                if unreachable {
                    Text("unreachable").font(.caption).foregroundStyle(.orange)
                }
            }
            if agents.isEmpty {
                Text(unreachable ? "cannot reach host" : "no agents")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(agents, id: \.key) { agent in
                AgentRow(agent: agent,
                         displayName: names[agent.key] ?? agent.info.displayName,
                         isHighlighted: store.highlighted.contains(agent.key),
                         now: now)
            }
        }
    }
}

private struct AgentRow: View {
    let agent: TrackedAgent
    let displayName: String
    let isHighlighted: Bool
    let now: Date

    var body: some View {
        HStack(spacing: 8) {
            icon.frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(displayName).font(.body).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(agent.status.rawValue).font(.caption)
            Circle().fill(agent.status.dotColor).frame(width: 8, height: 8)
            Text(TimerFormatter.string(from: agent.since, to: now))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(agent.status.dotColor.opacity(isHighlighted ? 0.22 : 0))
        )
        .animation(.easeInOut(duration: 0.25), value: isHighlighted)
    }

    @ViewBuilder private var icon: some View {
        if let image = AgentIcons.image(for: AgentKind.from(label: agent.info.agent)) {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: "terminal").foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        let cwd = agent.info.cwd.map { URL(fileURLWithPath: $0).lastPathComponent } ?? ""
        return cwd.isEmpty ? agent.session : "\(agent.session) · \(cwd)"
    }
}
