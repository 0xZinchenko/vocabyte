# Manual testing checklist

This checklist does not require any Swift knowledge. Run through it after
each stage that touches the relevant area; not every item applies to every
stage yet (see notes).

## Stage 7: settings and CSV export

- [ ] "Settings" in the menu bar opens a window with a translation language
      picker (Russian/Ukrainian) and a hotkey recorder.
- [ ] Changing the translation language and then saving a new word uses the
      new language for its translation.
- [ ] Clicking the hotkey recorder and pressing a new key combo rebinds the
      save hotkey — the old combo stops working, the new one saves a word.
- [ ] In the word list window, "Export to CSV…" opens a save panel; picking
      a location writes a `.csv` file.
- [ ] The exported CSV opens in Excel/Numbers with Cyrillic translations
      displayed correctly (not mangled/question marks).
- [ ] Exporting while a search/filter is active in the word list still
      exports every word, not just the visible/filtered ones.

Not yet manually tested — build and the automated test suite
(`CSVExporterTests`) pass, but no one has clicked through Settings or
exported a real file yet.

## Stage 6: word list window

- [ ] "Open List" in the menu bar opens a window showing saved words (word,
      phonetic, part of speech, translation, repeat count).
- [ ] The list updates live — saving a new word via the hotkey while the
      window is open makes it appear without reopening the window, and a
      background translation arriving fills in the Translation column live.
- [ ] Checking the checkbox next to a word marks it learned; with the filter
      set to "Active" it then disappears from the list, and reappears when
      the filter is switched to "Learned" or "All".
- [ ] Typing in the search field filters the list by word or translation
      text.
- [ ] The sort picker re-orders the list by date / alphabetically / by
      repeat count as expected.
- [ ] Right-clicking a row (or selecting several and right-clicking) offers
      "Delete", and deleting removes the row from the database, not just the
      visible list (confirm via `sqlite3` after reopening the window).

Not yet manually tested — build and the automated test suite
(`DatabaseManagerTests`: `allWords`, `setLearned`, `deleteWord`) pass, but no
one has clicked through the actual window yet.

## Stage 5: dictionary and translation

- [x] After saving a new word, phonetic transcription, part of speech, and
      a Russian translation appear within a few seconds (confirmed via
      `sqlite3`), and `lookupStatus` becomes `success`.
- [x] A word the dictionary has no entry for (e.g. a less common inflected
      form) still gets a translation and `lookupStatus = success` — a
      missing dictionary entry alone doesn't block success.
- [ ] With no network connection, saving still works locally; translation
      and transcription appear later once the network is back. Not yet
      manually tested (needs toggling network off/on); automated tests
      cover the underlying retry logic (`WordLookupServiceTests`).
- [ ] Manual retry ("Refresh") isn't wired to any UI yet — the method
      exists (`WordLookupService.refreshPending()`) but there's no button
      until the word list (stage 6) exists.

Check progress so far with:
```
sqlite3 ~/Library/Application\ Support/Vocabyte/words.sqlite "select displayWord, phonetic, partOfSpeech, translation, lookupStatus from word order by rowid desc limit 5;"
```

## Stage 3: word capture

- [x] Selecting a word in Chrome and pressing the hotkey saves it (via
      Accessibility; no surrounding sentence is extracted for web page
      selections — expected, see below).
- [x] Selecting a word in Preview (PDF) and pressing the hotkey saves it.
- [x] Selecting a word in Safari and pressing the hotkey saves it.
- [x] Selecting a word in IntelliJ IDEA and pressing the hotkey saves it.
- [ ] Selecting a word in Terminal and pressing the hotkey does **not**
      currently save anything — neither Accessibility nor the clipboard
      fallback find a selection there. **Known issue, deliberately
      postponed**: suspected cause is Terminal's "Secure Keyboard Entry"
      setting, which can block both synthetic keystrokes and Accessibility
      reads app-wide. Revisit before calling this stage done.
- [x] Saving the same word twice increases its repeat count instead of
      creating a duplicate row (verified via `sqlite3`).
- [x] Selecting a very long piece of text is rejected (nothing saved; no
      visible feedback yet — that's stage 4). Confirmed via `log stream`
      showing "Selection rejected: too much text."
- [x] Accessibility permission: revoking it in System Settings and trying
      the hotkey shows the explanation dialog with a button to open System
      Settings.
- [x] Selecting text inside a password field and pressing the hotkey does
      **not** save or show anything containing the password — confirmed via
      `log stream` showing "Nothing selected." (the secure field hides its
      content from the Accessibility API, as expected).
- [x] Pressing the hotkey repeatedly (50+ times in a row) does not cause
      Vocabyte's memory usage to keep climbing — measured directly via
      `ps`: 85.0 MB before, 85.7 MB after 50 presses (~0.7 MB, one-off, not
      proportional to the number of presses).
- [x] With no selection and no hotkey activity, Vocabyte's CPU usage stays
      at ~0% (confirmed via `ps` alongside the memory check above).

Check progress so far with:
```
sqlite3 ~/Library/Application\ Support/Vocabyte/words.sqlite "select displayWord, count, sentence from word;"
log stream --predicate 'subsystem == "com.example.Vocabyte"'
```

## Stage 2: local database

No manual steps yet — this stage has no UI. Verified by the automated test
suite (`xcodebuild ... test`), which covers:

- Normalization: word/phrase length limits, rejecting multi-line or overly
  long selections, trimming edge punctuation, keeping internal
  apostrophes/hyphens, case-insensitive deduplication key.
- Database: saving a new word, repeat saves incrementing the counter instead
  of creating duplicate rows, and that the originally saved casing is kept.

## Stage 1: project scaffold

- [ ] `xcodegen generate` completes without errors.
- [ ] The app builds via `xcodebuild ... build`.
- [ ] The app launches and shows an icon in the menu bar (top right of the
      screen), with no icon in the Dock.
- [ ] Clicking the menu bar icon shows a menu with "Открыть список",
      "Настройки", and "Выйти" (the first two don't do anything yet — that's
      expected at this stage).
- [ ] "Выйти" quits the app.

## Not yet testable (added in later stages)

The items below describe the full checklist for the finished first version
of Vocabyte. They will be filled in and checked off stage by stage — most of
them are not implemented yet, so skip them for now:

- [ ] Changing the translation language in Settings affects new lookups.
- [ ] Exporting to CSV produces a file that opens correctly in Excel,
      including Cyrillic text.
- [ ] The save confirmation ("Saved: ..." / "Already saved ×N") appears
      briefly near the edge of the screen and disappears on its own.
- [ ] The save confirmation still appears when a fullscreen app or a
      different Space is active.
