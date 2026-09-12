import AppKit
import SwiftUI
import HerdviewCore

/// What every host is running: a summary of the whole herd, then one section
/// per host, most attention-worthy agent first. This is the window's whole
/// content. The tick lives here, and moves the elapsed times only: it runs at
/// half a second so a row never shows a stale second. The blink is not on this
/// clock at all — it is handed to Core Animation once and runs on its own.
struct AgentListView: View {
    /// Half a second, so the displayed second is never more than half a second
    /// behind the real one.
    private static let tick: TimeInterval = 0.5

    @ObservedObject var store: AgentStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: Self.tick)) { context in
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
    /// How far the blinking wash is held off the top and bottom of its row, so
    /// that two blinking neighbours stay two rows instead of merging into one
    /// block. Half the gap each, so the gap between them is twice this.
    static let washInset: CGFloat = 1.5
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
                // The session keeps the quiet type it had when it sat on the
                // second line: it says which herd the agent belongs to, not
                // what the agent is, so it rides beside the name rather than
                // competing with it.
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(text.primary)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let session = text.session {
                        Text(session)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .layoutPriority(-1)
                    }
                }
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
        .background(wash)
        .help(tooltip(for: text))
    }

    /// A blocked or done row blinks for as long as it stays that way — it is
    /// asking for a person, and it keeps asking until someone comes. Every
    /// other row is plain. Rows do not light up under the pointer, because
    /// clicking one does nothing and a hover highlight would promise that it
    /// did.
    ///
    /// The inset is applied out here rather than inside the wash so that the
    /// layer being animated fills its own view exactly, with nothing between
    /// the two to lay out.
    private var wash: some View {
        BlinkWash(status: agent.status)
            .padding(.vertical, Metrics.washInset)
    }

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

    /// Every line is truncated in the row, so the pointer can ask for the
    /// parts that did not fit — the directory spelled out in full, since that
    /// is the one the row shortens to its last component.
    private func tooltip(for text: AgentRowText) -> String {
        let lead = agent.info.cwd.flatMap { $0.isEmpty ? nil : $0 } ?? text.primary
        guard let session = text.session else { return "\(lead)\n\(text.secondary)" }
        return "\(lead) · \(session)\n\(text.secondary)"
    }
}

/// The breathing wash behind a blocked or done row.
///
/// Drawn by Core Animation rather than by SwiftUI. A wash redrawn through the
/// view graph costs a whole `NSHostingView` layout pass per frame — measured
/// at around fourteen points of CPU for two blinking rows, against a floor of
/// four for the rest of the app put together. Handed to Core Animation, the
/// interpolation happens on the render server: the app does nothing at all
/// between the moment the animation is added and the moment the status
/// changes, and the breath runs at the screen's own refresh rate instead of a
/// rate this code had to pick.
private struct BlinkWash: NSViewRepresentable {
    let status: AgentStatus

    func makeNSView(context: Context) -> WashView { WashView() }

    func updateNSView(_ view: WashView, context: Context) {
        view.show(status)
    }
}

/// A single layer that holds the row's colour and breathes.
private final class WashView: NSView {
    private static let breathKey = "breath"
    private var shown: AgentStatus?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        layer?.opacity = 0
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("not loaded from a nib") }

    /// Nothing here reacts to the pointer: this is the row's background, and
    /// letting it take part in hit testing would take the row's own tooltip
    /// away from it.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// The row above is rebuilt about twice a second, for the elapsed time and
    /// for every snapshot the herd pushes, so this is called that often with
    /// the status unchanged. Restarting the animation each time would jerk the
    /// breath back to its beginning twice a second and put the cost straight
    /// back; it must only act when something actually changed.
    func show(_ status: AgentStatus) {
        guard shown != status else { return }
        shown = status
        redraw()
    }

    /// A `CGColor` is resolved against whichever appearance was current when
    /// it was made, and unlike a SwiftUI `Color` it does not follow the system
    /// afterwards. Switching between light and dark has to resolve it again.
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        redraw()
    }

    /// A layer loses its animations when its view leaves the window, which
    /// this one does every time the window is closed to the menu bar.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { redraw() }
    }

    private func redraw() {
        guard let layer, let status = shown else { return }
        layer.removeAnimation(forKey: WashView.breathKey)

        guard let ends = status.washOpacity else {
            layer.opacity = 0
            layer.backgroundColor = nil
            return
        }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer.backgroundColor = status.nsTint.cgColor
        }

        let breath = CABasicAnimation(keyPath: "opacity")
        breath.fromValue = ends.dim
        breath.toValue = ends.bright
        breath.duration = BlinkPhase.period / 2
        breath.autoreverses = true
        breath.repeatCount = .infinity
        breath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        // Wound forward to wherever the clock already is, so a row that
        // appears now falls in step with the rows already breathing instead of
        // starting a beat of its own.
        let clock = CACurrentMediaTime()
        breath.beginTime = layer.convertTime(clock, from: nil)
            - BlinkPhase.secondsSinceDimmest(clock: clock)

        layer.opacity = Float(ends.dim)
        layer.add(breath, forKey: WashView.breathKey)
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
