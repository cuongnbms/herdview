import SwiftUI
import HerdPetCore

/// Which page the popover is showing. A view model, not `@State`, because
/// SwiftUI's property-wrapper macros are not available to every toolchain.
@MainActor
final class MenuViewModel: ObservableObject {
    enum Page { case agents, settings }

    @Published var page: Page = .agents

    func toggleSettings() { page = page == .settings ? .agents : .settings }
}

struct MenuContentView: View {
    @ObservedObject var store: AgentStore
    @ObservedObject var pet: PetModel
    @ObservedObject var menu: MenuViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch menu.page {
            case .agents:
                AgentList(store: store)
            case .settings:
                SettingsPage(pet: pet) { menu.page = .agents }
            }
            Divider()
            Footer(menu: menu)
        }
        .padding(12)
        .frame(width: 360)
        .onAppear { pet.refreshPacks() }
    }
}

/// Page one: what every host is running. The one-second tick lives here, since
/// the elapsed timers are the only thing on either page that moves on its own.
private struct AgentList: View {
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
        }
    }
}

/// Page two: which pet, how big, and which clip each mood plays. Everything
/// here applies live, so the floating pet is the preview.
private struct SettingsPage: View {
    @ObservedObject var pet: PetModel
    let back: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Button(action: back) {
                    Image(systemName: "chevron.left").font(.headline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Back to agents")
                Text("Settings").font(.headline)
                Spacer(minLength: 0)
            }
            PetPickerRow(pet: pet)
            PetSizeRow(pet: pet)
            AnimationSpeedRow(pet: pet)
            ClipBindingRows(pet: pet)
        }
    }
}

/// Version, the way into the settings, and the way out of the app.
private struct Footer: View {
    @ObservedObject var menu: MenuViewModel

    var body: some View {
        HStack(spacing: 10) {
            Text("HerdPet \(HerdPet.version)").font(.caption2).foregroundStyle(.tertiary)
            Spacer()
            Button(action: menu.toggleSettings) {
                Image(systemName: "gearshape")
                    .foregroundStyle(menu.page == .settings ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(menu.page == .settings ? "Back to agents" : "Settings")
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
        }
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

/// Sets how big the pet is drawn: three presets for a quick jump, a slider for
/// anything in between. The pet itself resizes live.
private struct PetSizeRow: View {
    @ObservedObject var pet: PetModel

    var body: some View {
        HStack(spacing: 8) {
            Text("Size").font(.headline)
            Slider(value: $pet.petPoint, in: PetSize.minimum...PetSize.maximum)
                .controlSize(.small)
            ForEach(PetSize.presets) { preset in
                Button(preset.name) { pet.petPoint = preset.point }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}

/// Sets how fast the clips play: three presets for a quick jump, a slider for
/// anything in between. The pet itself speeds up live.
private struct AnimationSpeedRow: View {
    @ObservedObject var pet: PetModel

    var body: some View {
        HStack(spacing: 8) {
            Text("Speed").font(.headline)
            Slider(value: $pet.animationSpeed, in: AnimationSpeed.minimum...AnimationSpeed.maximum)
                .controlSize(.small)
            ForEach(AnimationSpeed.presets) { preset in
                Button(preset.name) { pet.animationSpeed = preset.multiplier }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}

/// Binds a spritesheet clip to each state. Collapsed by default: most packs
/// come out right with the default row order, and the live pet is the preview.
private struct ClipBindingRows: View {
    @ObservedObject var pet: PetModel

    var body: some View {
        if pet.clipCount > 1 {
            DisclosureGroup("Animation per state") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Mood.allCases, id: \.self) { mood in
                        HStack(spacing: 8) {
                            Text(mood.rawValue).font(.caption)
                            Spacer()
                            Picker("", selection: Binding(
                                get: { pet.clip(for: mood) },
                                set: { pet.bindClip($0, to: mood) }
                            )) {
                                ForEach(0..<pet.clipCount, id: \.self) { index in
                                    Text("Clip \(index + 1)").tag(index)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .controlSize(.small)
                            .frame(width: 110)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .font(.headline)
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
                AgentRow(agent: agent, displayName: names[agent.key] ?? agent.info.displayName, now: now)
            }
        }
    }
}

private struct AgentRow: View {
    let agent: TrackedAgent
    let displayName: String
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
