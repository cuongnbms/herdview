import SwiftUI
import HerdPetCore

struct MenuContentView: View {
    @ObservedObject var store: AgentStore
    @ObservedObject var pet: PetModel

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
                Divider()
                PetPickerRow(pet: pet)
                Divider()
                HStack {
                    Text("HerdPet \(HerdPet.version)").font(.caption2).foregroundStyle(.tertiary)
                    Spacer()
                    Button("Quit") { NSApp.terminate(nil) }
                        .buttonStyle(.plain)
                        .font(.caption)
                }
            }
            .padding(12)
            .frame(width: 360)
        }
        .onAppear { pet.refreshPacks() }
    }
}

/// Picks the pet pack from `~/.agentpet/pets`. The choice is remembered and
/// overrides `pet` in the config file.
private struct PetPickerRow: View {
    @ObservedObject var pet: PetModel

    var body: some View {
        HStack(spacing: 8) {
            Text("Pet").font(.headline)
            Spacer()
            if pet.packs.isEmpty {
                Text("No packs in \(PetPackLoader.petsDir.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Picker("Pet", selection: Binding(
                    get: { pet.selectedPetID ?? "" },
                    set: { pet.selectPet(id: $0) }
                )) {
                    if pet.selectedPetID == nil {
                        Text("Choose…").tag("")
                    }
                    ForEach(pet.packs) { pack in
                        Text(pack.displayName).tag(pack.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
            }
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
                AgentRow(agent: agent, now: now)
            }
        }
    }
}

private struct AgentRow: View {
    let agent: TrackedAgent
    let now: Date

    var body: some View {
        HStack(spacing: 8) {
            icon.frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(agent.info.displayName).font(.body).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Circle().fill(color).frame(width: 8, height: 8)
            Text(agent.status.rawValue).font(.caption)
            Text(TimerFormatter.string(from: agent.since, to: now))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.vertical, 2)
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

    private var color: Color {
        switch agent.status {
        case .blocked: return .orange
        case .working: return .green
        case .done: return .blue
        case .idle, .unknown: return .gray
        }
    }
}
