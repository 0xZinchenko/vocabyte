import AppKit
import SwiftUI

/// A small, unobtrusive notice shown briefly after a hotkey press — never
/// steals focus, never intercepts clicks, and hides itself after ~1.7s.
/// Not guaranteed by Apple's documentation to stay above every fullscreen
/// app and on every Space; that's verified manually (see TESTING.md).
final class SaveFeedbackPanel: NSPanel {
    static let shared = SaveFeedbackPanel()

    private static let size = NSSize(width: 280, height: 44)
    private static let screenMargin: CGFloat = 16
    private static let visibleDuration: TimeInterval = 1.7
    private static let fadeOutDuration: TimeInterval = 0.25

    private let content = SaveFeedbackContent()
    private var hideTimer: Timer?

    private init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isMovable = false
        isReleasedWhenClosed = false
        // Never takes focus or intercepts clicks — the whole point is to be
        // seen without interrupting whatever the user was doing.
        ignoresMouseEvents = true
        hidesOnDeactivate = false

        let hostingView = NSHostingView(rootView: SaveFeedbackView(content: content))
        hostingView.frame = NSRect(origin: .zero, size: Self.size)
        self.contentView = hostingView
    }

    /// Must be called on the main thread.
    func show(message: String) {
        hideTimer?.invalidate()
        content.message = message
        positionOnScreenWithCursor()
        alphaValue = 1
        orderFrontRegardless()

        hideTimer = Timer.scheduledTimer(withTimeInterval: Self.visibleDuration, repeats: false) { [weak self] _ in
            self?.fadeOutAndHide()
        }
    }

    private func fadeOutAndHide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.fadeOutDuration
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
        })
    }

    /// Picks the top-right corner of whichever screen currently has the
    /// mouse cursor, so the panel shows up where the user is actually
    /// looking on multi-monitor setups.
    private func positionOnScreenWithCursor() {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let screen else { return }

        let origin = NSPoint(
            x: screen.frame.maxX - Self.size.width - Self.screenMargin,
            y: screen.frame.maxY - Self.size.height - Self.screenMargin
        )
        setFrameOrigin(origin)
    }
}
