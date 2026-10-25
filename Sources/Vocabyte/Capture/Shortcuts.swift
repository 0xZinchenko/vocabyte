import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Default: Ctrl+Option+D. Deliberately not Cmd+D, which is already a
    /// common shortcut (e.g. "bookmark this page") in many apps.
    static let saveSelectedWord = Self("saveSelectedWord", default: .init(.d, modifiers: [.control, .option]))
}
