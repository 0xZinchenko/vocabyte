import ApplicationServices
import Foundation

/// Primary capture method: reads the selected text directly from whatever
/// UI element currently has focus, via the system Accessibility API.
/// Works well for native (Cocoa) apps; apps with incomplete Accessibility
/// support (some Electron apps, some Java/Swing apps) may not expose a
/// selection this way, in which case `ClipboardFallbackCapture` is used.
enum AccessibilityCapture {
    static func captureSelection() -> CapturedSelection? {
        guard let element = focusedElement(), let text = selectedText(of: element) else {
            return nil
        }
        let sentence = surroundingSentence(of: element) ?? ""
        return CapturedSelection(text: text, sentence: sentence)
    }

    private static func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedAppValue: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppValue) == .success,
              let focusedApp = focusedAppValue
        else {
            return nil
        }

        var focusedElementValue: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElementValue) == .success,
              let focusedElement = focusedElementValue
        else {
            return nil
        }

        return (focusedElement as! AXUIElement)
    }

    private static func selectedText(of element: AXUIElement) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value) == .success,
              let text = value as? String,
              !text.isEmpty
        else {
            return nil
        }
        return text
    }

    /// Best-effort: reads the whole field's text and the selection's range
    /// within it, to cut out the sentence around the selection. Not every
    /// element exposes these attributes, so returning `nil` here is normal
    /// and expected — it's not an error, the word is still saved with an
    /// empty sentence.
    private static func surroundingSentence(of element: AXUIElement) -> String? {
        var valueRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let fullText = valueRef as? String
        else {
            return nil
        }

        var rangeRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let axRangeValue = rangeRef
        else {
            return nil
        }

        var cfRange = CFRange()
        guard AXValueGetValue(axRangeValue as! AXValue, .cfRange, &cfRange) else {
            return nil
        }

        return SentenceExtractor.extractSentence(
            from: fullText,
            selectionLocation: cfRange.location,
            selectionLength: cfRange.length
        )
    }
}
