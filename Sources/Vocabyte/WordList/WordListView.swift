import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum WordListSort: String, CaseIterable, Identifiable {
    case dateAdded = "Date"
    case alphabetical = "A–Z"
    case mostFrequent = "Most frequent"

    var id: String { rawValue }
}

enum WordListFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case active = "Active"
    case learned = "Learned"

    var id: String { rawValue }
}

/// The word list's editable name cell: a learned checkbox plus a text field
/// that lets the user correct a capture mistake (a dropped letter, a stray
/// bracket) in place, without deleting and re-saving the word.
private struct WordNameCell: View {
    let word: Word
    let store: WordListStore

    @State private var text: String

    init(word: Word, store: WordListStore) {
        self.word = word
        self.store = store
        _text = State(initialValue: word.displayWord)
    }

    var body: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { word.learned },
                set: { store.setLearned(word, learned: $0) }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()

            TextField("Word", text: $text)
                .textFieldStyle(.plain)
                .onSubmit {
                    store.rename(word, to: text)
                }
        }
    }
}

struct WordListView: View {
    @StateObject private var store = WordListStore()
    @State private var searchText = ""
    @State private var sort: WordListSort = .dateAdded
    @State private var filter: WordListFilter = .active
    @State private var exportError: String?

    private var visibleWords: [Word] {
        var words = store.words

        switch filter {
        case .all:
            break
        case .active:
            words = words.filter { !$0.learned }
        case .learned:
            words = words.filter(\.learned)
        }

        if !searchText.isEmpty {
            words = words.filter {
                $0.displayWord.localizedCaseInsensitiveContains(searchText)
                    || ($0.translation?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        switch sort {
        case .dateAdded:
            break // allWords() is already newest-captured first.
        case .alphabetical:
            words.sort { $0.displayWord.localizedCaseInsensitiveCompare($1.displayWord) == .orderedAscending }
        case .mostFrequent:
            words.sort { $0.count > $1.count }
        }

        return words
    }

    var body: some View {
        Group {
            if visibleWords.isEmpty {
                emptyState
            } else {
                wordTable
            }
        }
        .searchable(text: $searchText, prompt: "Search word or translation")
        .frame(minWidth: 640, minHeight: 400)
        .toolbar {
            ToolbarItemGroup {
                Picker("Filter", selection: $filter) {
                    ForEach(WordListFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Sort", selection: $sort) {
                    ForEach(WordListSort.allCases) { sort in
                        Text(sort.rawValue).tag(sort)
                    }
                }

                Button {
                    exportCSV()
                } label: {
                    Label("Export to CSV…", systemImage: "square.and.arrow.up")
                }
            }
        }
        .alert("Export failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    /// Kept out of the view tree entirely when `visibleWords` is empty — a
    /// `Table` with zero rows crashes if right-clicked (SwiftUI/AppKit bug:
    /// `.contextMenu(forSelectionType:)` can hand the underlying
    /// `NSTableView` a row index of -1), so this avoids ever having a
    /// zero-row `Table` with that modifier attached, rather than trying to
    /// work around the crash some other way.
    private var wordTable: some View {
        Table(visibleWords) {
            TableColumn("Word") { word in
                WordNameCell(word: word, store: store)
            }
            TableColumn("Phonetic") { word in
                Text(word.phonetic ?? "")
            }
            TableColumn("Translation") { word in
                Text(word.translation ?? "")
            }
            TableColumn("Part of speech") { word in
                Text(word.partOfSpeech ?? "")
            }
            TableColumn("Count") { word in
                Text("\(word.count)")
            }
        }
        .contextMenu(forSelectionType: Word.ID.self) { ids in
            Button("Delete", role: .destructive) {
                for word in visibleWords where ids.contains(word.id) {
                    store.delete(word)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 36))
                .foregroundStyle(AppColor.textSecondary)
            Text(store.words.isEmpty ? "No words yet" : "No matches")
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.background)
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "vocabyte-export.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try CSVExporter.write(store.words, to: url)
        } catch {
            exportError = error.localizedDescription
        }
    }
}
