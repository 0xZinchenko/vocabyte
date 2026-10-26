# Manual testing checklist

This checklist does not require any Swift knowledge. Run through it after
each stage that touches the relevant area; not every item applies to every
stage yet (see notes).

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

- [ ] With no network connection, saving still works locally; translation
      and transcription appear later once the network is back (use
      "Refresh").
- [ ] Changing the translation language in Settings affects new lookups.
- [ ] Exporting to CSV produces a file that opens correctly in Excel,
      including Cyrillic text.
- [ ] The save confirmation ("Saved: ..." / "Already saved ×N") appears
      briefly near the edge of the screen and disappears on its own.
- [ ] The save confirmation still appears when a fullscreen app or a
      different Space is active.
