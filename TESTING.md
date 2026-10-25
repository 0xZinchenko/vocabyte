# Manual testing checklist

This checklist does not require any Swift knowledge. Run through it after
each stage that touches the relevant area; not every item applies to every
stage yet (see notes).

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

- [ ] Selecting a word in Safari and pressing the hotkey saves it.
- [ ] Selecting a word in IntelliJ IDEA and pressing the hotkey saves it.
- [ ] Selecting a word in Preview and pressing the hotkey saves it.
- [ ] Selecting a word in Terminal and pressing the hotkey saves it.
- [ ] Saving the same word twice increases its repeat count instead of
      creating a duplicate row.
- [ ] Selecting a very long piece of text shows "Слишком много текста, не
      сохранено" and does not save anything.
- [ ] With no network connection, saving still works locally; translation
      and transcription appear later once the network is back (use
      "Обновить").
- [ ] Changing the translation language in Settings affects new lookups.
- [ ] Exporting to CSV produces a file that opens correctly in Excel,
      including Cyrillic text.
- [ ] Accessibility permission: revoking it in System Settings and trying
      the hotkey shows an explanation instead of silently failing.
- [ ] The save confirmation ("Сохранено" / "Уже было, N-й раз") appears
      briefly near the edge of the screen and disappears on its own.
- [ ] The save confirmation still appears when a fullscreen app or a
      different Space is active.
- [ ] Selecting text inside a password field and pressing the hotkey does
      **not** save or show anything containing the password (macOS secure
      text fields are expected to hide their content from the Accessibility
      API; confirm this holds in practice, e.g. in Safari's or System
      Settings' password fields).
- [ ] Pressing the hotkey repeatedly (50+ times in a row) does not cause
      Vocabyte's memory usage (Activity Monitor) to keep climbing — it
      should return close to its baseline between presses, not grow
      unbounded.
- [ ] With no selection and no hotkey activity, Vocabyte's CPU usage in
      Activity Monitor stays at ~0% (it should only do work when the hotkey
      is pressed or a window is open).
