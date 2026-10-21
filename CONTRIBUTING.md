# Contributing to Balai

Thanks for helping! Balai deletes files on people's Macs, so we care about two things above all: **safety** and **clarity**. Everything below follows from that.

*Les contributions en français sont les bienvenues aussi : issues, PR et commentaires de code.*

## Quick start

```bash
git clone https://github.com/root-lr/Balai.git
cd Balai
swift run      # launch the app
swift test     # run the tests (must pass before any PR)
```

Requirements: macOS 13+, Xcode 15+. You can also open `Package.swift` in Xcode.

## Ways to contribute

- 🐛 **Report a bug**: use the *Bug report* template, with your macOS version and steps to reproduce.
- 🧹 **Propose a new cleanup location**: use the *New cleanup location* template (see the rule below).
- ✨ **Suggest a feature**: use the *Feature request* template. Check the [roadmap](README.md#%EF%B8%8F-roadmap) first.
- 🌍 **Translate**: see [Localization](#localization).
- 🧑‍💻 **Write code**: issues labeled `good first issue` are a good start. For anything big, open an issue first so we can agree on the approach.

## The one rule for cleanup locations

Every new path Balai proposes to delete must come with:

1. **Why it's safe to delete**, ideally with a link (Apple docs, the tool's docs, a well-known discussion).
2. **Whether it regenerates on its own** (a cache) or is gone for good (user data).
3. **The right risk level**: `.safe` and pre-selected only if it regenerates and holds no user data; otherwise `.review` and not pre-selected.

When in doubt, choose `.review`. A cleaner that removes too little is annoying; one that removes too much is dangerous.

## How the code is organized

```
Sources/Balai/
├── Core/          # models, SafetyGuard, Deleter, permissions, localization
├── Modules/       # one scanner per module, the uninstaller, the disk explorer
├── ViewModels/    # app state (SwiftUI, @MainActor)
└── Views/         # theme, shared components, one view per screen
```

- **`SafetyGuard`** is the last check before any deletion. **Never bypass it** and never delete files outside `Deleter`. Changes to `SafetyGuard` need tests in `Tests/BalaiTests/SafetyGuardTests.swift`.
- **A new cleanup module** is a type conforming to `Scanner` that returns `[CleanupItem]`. `ScanViewModel` and `CleanupModuleView` give you the scan, review, confirmation and deletion flow for free.
- **The interface** uses the components in `Views/Theme.swift` (`HeroPage`, `ScanButton`, `PillButton`, `GhostButton`, `panel()`). Please reuse them rather than styling from scratch, so every screen feels the same.

## Localization

Balai ships in English and French. Every user-facing string goes through:

```swift
L("Texte en français", "English text")
```

Don't add a string without both languages; if you can't write one of them, say so in your PR and we'll help. Adding a new language is welcome: open an issue first, since it means moving to a string catalog.

## Code style

- Match the surrounding code: naming, structure and comment density. Comments explain *why*, not *what*.
- The project builds with **zero warnings** in debug and release; keep it that way.
- The minimum target is **macOS 13**: guard newer APIs with `if #available`.
- Keep pull requests focused: one feature or fix per PR.

## Seeing your UI changes

Debug builds can capture the window without screen-recording permission, which is handy for PR screenshots:

```bash
BALAI_PAGE=caches BALAI_AUTOSCAN=1 BALAI_SNAPSHOT=/tmp/shot.png swift run
```

| Variable | Effect |
|---|---|
| `BALAI_SNAPSHOT=<path>` | Saves a PNG of the window, then quits |
| `BALAI_SNAPSHOT_DELAY=<s>` | Waits before capturing (default: 3) |
| `BALAI_PAGE=<module>` | `caches`, `devFiles`, `largeFiles`, `uninstaller`, `spaceLens` |
| `BALAI_AUTOSCAN=1` | Starts the scan on launch |
| `BALAI_DETAILS=1` | Opens the details list after a module scan |
| `BALAI_APP=<name>` | Selects an app in the uninstaller |
| `BALAI_OPEN=<a/b/c>` | Opens a folder in the Space Explorer after the scan |

Add `-AppleLanguages "(fr)"` to see the French interface. These hooks only exist in debug builds.

## Pull request checklist

- [ ] `swift build` and `swift test` pass, with no new warnings
- [ ] New strings use `L("…", "…")` with both languages
- [ ] New cleanup locations explain why they're safe (see the rule above)
- [ ] UI changes include a screenshot

## Security issues

Please **don't** open a public issue for a way to make Balai delete something it shouldn't. See [SECURITY.md](SECURITY.md).

## Code of conduct

Be kind and constructive. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
