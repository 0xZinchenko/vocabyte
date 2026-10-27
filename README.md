# Vocabyte

Vocabyte is a native macOS menu-bar app for programmers who read English books
and technical documentation. Press a global hotkey to save the selected word
or phrase; Vocabyte looks it up in the background (phonetic transcription,
part of speech, translation) and keeps everything in a local, searchable,
editable list.

No server, no account, no sync — everything lives in a local SQLite database
on your Mac.

## Why

Reading English technical books and documentation means constantly running
into unfamiliar words — stopping to look each one up and write it down
somewhere breaks the reading flow. Vocabyte exists to remove that friction:
one hotkey press saves the word with its surrounding context, looks up the
meaning in the background, and gets out of the way immediately.

It deliberately does one thing well instead of trying to be a full
flashcard/spaced-repetition app — export to CSV if you want to feed your
list into something built for that.

## Features

- **Global hotkey capture** — select a word or short phrase anywhere (web
  pages, PDFs, IDEs, most native apps) and press the hotkey to save it, with
  the surrounding sentence kept for context where the source app exposes it.
- **Background lookup** — phonetic transcription and part of speech (Free
  Dictionary API) plus translation (MyMemory) are fetched automatically after
  saving and retried on next launch if they failed.
- **Word list window** — search, filter (All / Active / Learned), sort (date
  captured / alphabetical / most frequent), mark words learned, edit a word's
  text in place to fix a capture mistake, and delete entries.
- **CSV export** — exports the full word list (word, phonetic, translation,
  part of speech, sentence, repeat count, learned status, dates) with a
  UTF-8 BOM so Cyrillic translations display correctly in Excel.
- **Settings** — translation target language (Russian/Ukrainian), a
  rebindable hotkey, launch-at-login, and an explicit light/dark appearance
  toggle.
- Repeat saves of the same word increment a counter instead of creating
  duplicates; a dropped first selection fills in a missing sentence later
  without overwriting one already saved.

## Requirements

- macOS 13 (Ventura) or newer
- Xcode 15 or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — generates the Xcode
  project from `project.yml` (the project file itself is not checked into
  git; it's regenerated on demand)

Install XcodeGen with Homebrew:

```sh
brew install xcodegen
```

## Build and run

```sh
xcodegen generate
xcodebuild -project Vocabyte.xcodeproj -scheme Vocabyte -configuration Debug build
```

Or open `Vocabyte.xcodeproj` in Xcode after generating it and run with ⌘R.

Run the test suite:

```sh
xcodebuild -project Vocabyte.xcodeproj -scheme Vocabyte -configuration Debug test
```

Re-run `xcodegen generate` any time `project.yml` changes (new source files,
new dependencies, new settings).

A Debug build (the default above) carries extra debug overhead; build with
`-configuration Release` for day-to-day use if you care about memory
footprint.

## Bundle identifier and code signing

The default bundle identifier is `com.example.Vocabyte`, set in `project.yml`
under `targets.Vocabyte.settings.base.PRODUCT_BUNDLE_IDENTIFIER`. Change it
there if you plan to keep Accessibility permissions across machines.

Local builds are signed with a free **Apple Development** certificate
(`CODE_SIGN_STYLE: Automatic`, `DEVELOPMENT_TEAM` set in `project.yml`) rather
than ad-hoc signing, because this makes macOS reset the Accessibility
permission (see below) less often across rebuilds.

To use your own Apple ID instead of the one already configured:

1. In Xcode: **Xcode → Settings → Accounts → + → Apple ID**, sign in with any
   Apple ID (no paid Developer Program membership needed).
2. Note your **Team ID** shown next to the account.
3. In `project.yml`, replace `DEVELOPMENT_TEAM` with your own Team ID.
4. Run `xcodegen generate` again.

Even with a real signing identity, macOS is not guaranteed to preserve the
Accessibility grant across every rebuild — this depends on internal macOS
behavior that is not fully documented and can change between macOS versions.

## Accessibility permission

Vocabyte reads the selected text from other apps using the Accessibility
API, which requires you to grant it permission once:

**System Settings → Privacy & Security → Accessibility** → enable Vocabyte.

If the permission disappears after a rebuild, just re-enable it the same way.

Capture doesn't work in terminal emulators (Terminal.app, iTerm2, Warp,
Ghostty, Alacritty, kitty, WezTerm, Hyper) — their custom-rendered text isn't
exposed via Accessibility, and Terminal.app's "Secure Keyboard Entry", when
enabled, also blocks the clipboard-based fallback. The hotkey shows "Not
supported in terminal apps" in that case instead of failing silently.

## Where your data lives

- Database: `~/Library/Application Support/Vocabyte/words.sqlite` (SQLite,
  readable with any SQLite browser or the `sqlite3` CLI).
- Preferences (translation language, theme, hotkey, launch-at-login): macOS
  `UserDefaults` for the app's bundle identifier.

Nothing is synced or uploaded anywhere except the two lookup APIs below.
Deleting a word in the app is permanent (no trash/undo) — use **Export to
CSV…** in the word list window beforehand if you want a backup.

## External services and their limits

Vocabyte calls two free, keyless public APIs in the background, after a word
is already saved locally:

- [Free Dictionary API](https://dictionaryapi.dev/) — phonetic transcription
  and part of speech. Coverage is uneven, especially for phrases; missing
  data is expected and not an error.
- [MyMemory](https://mymemory.translated.net/doc/spec.php) — translation.
  Has an unauthenticated daily usage limit; expect occasional failures under
  heavy use.

Both calls use an 8-second timeout. If a lookup fails, the word stays saved
locally and is retried automatically on next launch.

## Known technical trade-offs

- No App Sandbox: required by the current Accessibility API approach.
- No notarization/distribution signing at this stage — this is a local
  development build only.
- No telemetry, analytics, or network calls beyond the two APIs above.
- Normalization only checks word/phrase count, length, and line breaks — it
  does not try to detect "this looks like code" (e.g. `x = 1;`) or filter out
  non-English text. Both would need heuristics prone to false positives, with
  no precise rule given by the spec, so this was deliberately left out rather
  than guessed at.
- The word list's table header and row-selection highlight color follow the
  system appearance rather than the app's own theme — SwiftUI's `Table`
  doesn't expose a way to restyle those.

## License

MIT — see [LICENSE](LICENSE).
