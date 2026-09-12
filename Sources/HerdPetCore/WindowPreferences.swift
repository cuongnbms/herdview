import Foundation

/// The handful of window choices the user makes with the mouse and expects to
/// find again next launch. The window's frame is already remembered by AppKit's
/// own autosave; this covers what AppKit does not, starting with whether the
/// window floats above other apps.
public struct WindowPreferences {
    private static let alwaysOnTopKey = "herdpet.alwaysOnTop"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Off until the user asks for it: a window that covers other apps is a
    /// surprise to be opted into, not a default.
    public var isAlwaysOnTop: Bool {
        get { defaults.bool(forKey: Self.alwaysOnTopKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.alwaysOnTopKey) }
    }
}
