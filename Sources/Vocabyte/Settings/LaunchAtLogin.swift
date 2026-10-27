import ServiceManagement

/// Wraps `SMAppService` for the "launch at login" toggle. The system itself
/// is the source of truth for whether the login item is registered — not
/// something mirrored into `UserDefaults` — so this always reflects the
/// real current state instead of risking it drifting out of sync.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
