# Vocabyte

Vocabyte is a native macOS menu bar app for programmers who read English books
and technical documentation. Press a global hotkey to save the selected word
or phrase; Vocabyte looks it up in the background (phonetic transcription,
part of speech, translation) and keeps everything in a local, searchable list.

No server, no account, no sync — everything lives in a local SQLite database
on your Mac.

## Status

Early development. This README will grow as each stage lands. Current stage:
project scaffold (empty menu bar app, no hotkey capture or storage yet).

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

## Bundle identifier and code signing

The default bundle identifier is `com.example.Vocabyte`, set in `project.yml`
under `targets.Vocabyte.settings.base.PRODUCT_BUNDLE_IDENTIFIER`. Change it
there if you plan to keep Accessibility permissions across machines.

Local builds currently use **ad-hoc signing** (`CODE_SIGN_IDENTITY: "-"`, no
Apple Developer account required). This is enough to build and run the app,
but macOS can reset the Accessibility permission (see below) more often with
ad-hoc signing than with a real signing identity.

To reduce how often that happens, sign with a free **Apple Development**
certificate instead:

1. In Xcode: **Xcode → Settings → Accounts → + → Apple ID**, sign in with any
   Apple ID (no paid Developer Program membership needed).
2. Note your **Team ID** shown next to the account.
3. In `project.yml`, change the signing settings to:
   ```yaml
   CODE_SIGN_STYLE: Automatic
   DEVELOPMENT_TEAM: "<your Team ID>"
   ```
   and remove the `CODE_SIGN_IDENTITY: "-"` line.
4. Run `xcodegen generate` again.

Even with a real signing identity, macOS is not guaranteed to preserve the
Accessibility grant across every rebuild — this depends on internal macOS
behavior that is not fully documented and can change between macOS versions.

## Accessibility permission

Vocabyte reads the selected text from other apps using the Accessibility
API, which requires you to grant it permission once:

**System Settings → Privacy & Security → Accessibility** → enable Vocabyte.

If the permission disappears after a rebuild (common with ad-hoc signing),
just re-enable it the same way. The app's Settings window shows the current
permission status and a shortcut to this System Settings pane (added in a
later stage).

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
locally and is retried later (on next launch or via the "Обновить" button).

## Known technical trade-offs

- No App Sandbox: required by the current Accessibility API approach.
- No notarization/distribution signing at this stage — this is a local
  development build only.
- No telemetry, analytics, or network calls beyond the two APIs above.

## License

MIT — see [LICENSE](LICENSE).
