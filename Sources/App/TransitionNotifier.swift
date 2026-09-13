import AppKit
import Combine
import HerdviewCore
import UserNotifications

/// Posts a macOS notification when an agent starts asking for a person.
///
/// The blinking row only reaches someone looking at the window; this reaches
/// them when they are in an editor, on another desktop, or away from the Mac.
/// Which transitions are worth it is `TransitionNotice`'s decision, not this
/// class's — here there is only the delivery.
///
/// There is deliberately no switch for it in the app. macOS already owns that
/// switch, per-app, in System Settings › Notifications, and a second one in
/// here could only disagree with it.
@MainActor
final class TransitionNotifier: NSObject {
    private let store: AgentStore
    private let onOpen: () -> Void
    private var cancellable: AnyCancellable?

    init(store: AgentStore, onOpen: @escaping () -> Void) {
        self.store = store
        self.onOpen = onOpen
        super.init()
    }

    func start() {
        // `UNUserNotificationCenter.current()` does not fail politely outside an
        // app bundle: it traps on a nil bundle proxy and takes the process with
        // it. `make run` opens the bundle and is fine; a bare `swift run`, or
        // the binary straight out of `.build`, is not — and that is exactly how
        // this app gets debugged. So ask before touching the centre at all.
        guard Bundle.main.bundleIdentifier != nil else { return }

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                NSLog("herdview: notification authorization failed: \(error)")
            } else if !granted {
                NSLog("herdview: notifications not permitted; rows still blink")
            }
        }

        cancellable = store.transitions.sink { [weak self] transitions in
            self?.post(transitions)
        }
    }

    private func post(_ transitions: [Transition]) {
        let center = UNUserNotificationCenter.current()
        for notice in transitions.compactMap(TransitionNotice.init) {
            let content = UNMutableNotificationContent()
            content.title = notice.title
            content.subtitle = notice.subtitle
            content.body = notice.body
            content.sound = .default
            content.threadIdentifier = notice.threadIdentifier
            // Keyed by the agent, so an agent that goes blocked, then done,
            // then blocked again replaces its own banner instead of leaving a
            // stack of stale ones behind.
            let request = UNNotificationRequest(identifier: notice.identifier,
                                                content: content, trigger: nil)
            center.add(request) { error in
                if let error {
                    NSLog("herdview: could not post notification: \(error)")
                }
            }
        }
    }
}

extension TransitionNotifier: UNUserNotificationCenterDelegate {
    /// Clicking a banner asks to see the agent it is about, so bring the window
    /// up. There is nothing finer to go to — the window is one list — so it
    /// opens on the list with the blinking row already in it.
    ///
    /// `nonisolated` because the centre calls its delegate without knowing
    /// about actors; the work itself hops to the main actor, where the window
    /// lives.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            onOpen()
            completionHandler()
        }
    }

    /// No `willPresent` override on purpose. Without one macOS withholds the
    /// banner while Herdview is frontmost, which is the behaviour to want: if
    /// the window is in front of you the row is already blinking, and a banner
    /// over it would cover the list it is pointing at. The notification is
    /// still filed in Notification Center either way.
}
