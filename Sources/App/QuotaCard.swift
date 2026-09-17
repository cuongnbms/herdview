import SwiftUI
import HerdviewCore

/// How much of each Provider's Quota is used, above the Hosts. One row per
/// Provider, always, so a missing row can never be read as "no limit".
struct QuotaCard: View {
    @ObservedObject var store: QuotaStore
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quota")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Metrics.textInset)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(QuotaProvider.allCases.enumerated()), id: \.element) { index, provider in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(maxWidth: .infinity)
                            .frame(height: 1)
                            .padding(.leading, Metrics.textInset + QuotaRow.textLeading)
                    }
                    QuotaRow(provider: provider, entry: store.entry(for: provider), now: now)
                        .padding(.horizontal, Metrics.cardInset)
                }
            }
            .cardSurface()
        }
    }
}

private struct QuotaRow: View {
    static let textLeading: CGFloat = iconSide + iconGap
    private static let iconSide: CGFloat = 26
    private static let iconGap: CGFloat = 10

    let provider: QuotaProvider
    let entry: QuotaEntry
    let now: Date

    var body: some View {
        HStack(alignment: .top, spacing: Self.iconGap) {
            icon
            VStack(alignment: .leading, spacing: 4) {
                FlowLayout(spacing: 14, lineSpacing: 4) {
                    providerName
                    inlineContent
                }
                staleNote
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.rowInset)
        .padding(.vertical, 8)
    }

    /// The name is the first item in the same flow as the Windows. This keeps
    /// the approved icon → Provider → Window composition at normal widths and
    /// lets only the items that no longer fit move to following lines.
    private var providerName: some View {
        Text(provider.displayName)
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
            .fixedSize()
    }

    @ViewBuilder private var inlineContent: some View {
        switch entry {
        case .loading:
            EmptyView()
        case .notSignedIn:
            note("not signed in")
        case .ok(let report):
            gauges(report.windows, dimmed: false)
        case .problem(let problem, let last):
            if let last {
                gauges(last.windows, dimmed: true)
            } else {
                note(problem.message(for: provider))
            }
        }
    }

    @ViewBuilder private var staleNote: some View {
        if case .problem(let problem, let last?) = entry {
            note("\(problem.message(for: provider)) · \(QuotaFormat.updatedAgo(last.fetchedAt, now: now))")
        }
    }

    @ViewBuilder private func gauges(_ windows: [QuotaWindow], dimmed: Bool) -> some View {
        ForEach(Array(windows.enumerated()), id: \.offset) { _, window in
            WindowGauge(window: window, now: now)
                .opacity(dimmed ? 0.45 : 1)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.06))
            if let image = AgentIcons.image(for: provider.agentKind) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }
        }
        .frame(width: Self.iconSide, height: Self.iconSide)
    }
}

/// One Window: its label, a thin bar, the percent used, and the time to Reset.
///
/// Warning colour goes on the bar only. Text stays on the label colours, as it
/// does everywhere in this app, because orange text does not reach a readable
/// contrast against a light window at this size; a Window near its limit says
/// so with a heavier weight instead.
private struct WindowGauge: View {
    private static let barWidth: CGFloat = 44

    let window: QuotaWindow
    let now: Date

    var body: some View {
        let warning = window.usedPercent >= QuotaFormat.warningPercent
        HStack(spacing: 5) {
            Text(window.label)
                .foregroundStyle(.secondary)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule()
                    .fill(warning ? Color(nsColor: .systemOrange) : Color.secondary)
                    .frame(width: Self.barWidth * window.usedPercent / 100)
            }
            .frame(width: Self.barWidth, height: 4)
            Text(QuotaFormat.percent(window.usedPercent))
                .fontWeight(warning ? .semibold : .regular)
                .foregroundStyle(warning ? .primary : .secondary)
            if let until = QuotaFormat.untilReset(window.resetsAt, now: now) {
                Text("· \(until)")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.system(size: 11).monospacedDigit())
        .lineLimit(1)
        .fixedSize()
    }
}

/// Lays its children out left to right and wraps to a new line when the next
/// one does not fit, so a row's Windows fold under each other as the window
/// narrows instead of being cut off.
private struct FlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let placements = place(subviews, width: proposal.width ?? .infinity)
        let width = placements.map { $0.origin.x + $0.size.width }.max() ?? 0
        let height = placements.map { $0.origin.y + $0.size.height }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, frame) in zip(subviews, place(subviews, width: bounds.width)) {
            subview.place(at: CGPoint(x: bounds.minX + frame.origin.x, y: bounds.minY + frame.origin.y),
                          proposal: ProposedViewSize(frame.size))
        }
    }

    private func place(_ subviews: Subviews, width: CGFloat) -> [CGRect] {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return frames
    }
}
