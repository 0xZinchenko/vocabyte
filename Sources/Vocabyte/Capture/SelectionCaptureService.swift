/// Combines the primary (Accessibility) and fallback (clipboard) capture
/// methods. The fallback is only tried if the primary method found nothing.
enum SelectionCaptureService {
    static func captureSelection() -> CapturedSelection? {
        if let captured = AccessibilityCapture.captureSelection() {
            return captured
        }

        guard let text = ClipboardFallbackCapture.captureSelectedText(), !text.isEmpty else {
            return nil
        }
        // The clipboard fallback has no way to tell us the surrounding
        // sentence, so it's left empty, same as when Accessibility can't
        // find one either.
        return CapturedSelection(text: text, sentence: "")
    }
}
