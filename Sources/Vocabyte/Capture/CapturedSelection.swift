/// Raw text read from wherever the user had something selected, before
/// normalization/filtering. `sentence` is empty when no surrounding context
/// could be extracted.
struct CapturedSelection: Equatable {
    let text: String
    let sentence: String
}
