import Combine

/// Holds the text the feedback panel currently shows. A class (not a struct)
/// so the already-created `NSHostingView` can keep observing it across
/// repeated saves, instead of rebuilding the panel every time.
final class SaveFeedbackContent: ObservableObject {
    @Published var message: String = ""
}
