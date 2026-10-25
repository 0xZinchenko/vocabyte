# Manual testing checklist

This checklist does not require any Swift knowledge. Run through it after
each stage that touches the relevant area; not every item applies to every
stage yet (see notes).

## Current stage: project scaffold

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
