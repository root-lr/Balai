<div align="center">

<img src="docs/images/icon.png" alt="Balai" width="128" />

# Balai

### The free, open-source Mac cleaner.
**As polished as the paid ones, without the subscription, the telemetry or the scare tactics.**

<p>
  <a href="https://github.com/root-lr/Balai/releases/latest"><img src="https://img.shields.io/github/v/release/root-lr/Balai?style=for-the-badge&color=FF5FA2&label=release" alt="Latest release" /></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-111111?style=for-the-badge&logo=apple&logoColor=white" alt="macOS 13+" />
  <img src="https://img.shields.io/badge/Swift-5.9-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 5.9" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-8A3FE0?style=for-the-badge" alt="MIT License" /></a>
</p>
<p>
  <a href="https://github.com/root-lr/Balai/actions/workflows/build.yml"><img src="https://img.shields.io/github/actions/workflow/status/root-lr/Balai/build.yml?style=flat-square&label=build" alt="Build" /></a>
  <a href="https://github.com/root-lr/Balai/releases"><img src="https://img.shields.io/github/downloads/root-lr/Balai/total?style=flat-square&color=2F7BE8" alt="Downloads" /></a>
  <a href="https://github.com/root-lr/Balai/stargazers"><img src="https://img.shields.io/github/stars/root-lr/Balai?style=flat-square&color=FFB257" alt="Stars" /></a>
  <a href="CONTRIBUTING.md"><img src="https://img.shields.io/badge/PRs-welcome-3BE0B0?style=flat-square" alt="PRs welcome" /></a>
  <img src="https://img.shields.io/badge/telemetry-none-1FB36B?style=flat-square" alt="No telemetry" />
</p>

**English** · [Français](README.fr.md) · [Download](https://github.com/root-lr/Balai/releases/latest) · [Report a bug](https://github.com/root-lr/Balai/issues/new/choose) · [Contribute](CONTRIBUTING.md)

<br />

<img src="docs/images/smart-scan.png" alt="Balai Smart Scan" width="880" />

</div>

<br />

## ✨ Why Balai?

<table>
  <tr>
    <td width="33%" valign="top">
      <h3>🧹 Frees real space</h3>
      Caches, logs, Xcode leftovers, forgotten <code>node_modules</code>, big files, apps and the junk they leave behind. One click scans everything.
    </td>
    <td width="33%" valign="top">
      <h3>🛡️ Safe by design</h3>
      Nothing is deleted without your confirmation. Every path goes through one audited safety guard, covered by tests. Trash by default.
    </td>
    <td width="33%" valign="top">
      <h3>🔓 Free & open</h3>
      MIT license. No account, no network calls, no telemetry, no "Your Mac is at risk!" pop-ups. The code is short enough to read.
    </td>
  </tr>
</table>

## 🚀 Features

| | Module | What it does |
|:-:|---|---|
| ✨ | **Smart Scan** | Runs every cleanup module at once, shows what can go, cleans the selection in one click. |
| 🗄️ | **Caches & Logs** | App caches, logs and crash reports from `~/Library`. Apple system caches are flagged *Review* and never pre-selected. |
| 🔨 | **Developer Files** | Xcode DerivedData, DeviceSupport, simulator caches and previews; npm, Yarn, Bun, pnpm, Gradle, Maven, Cargo and CocoaPods caches; `node_modules` of projects you haven't touched in a while. |
| 🫧 | **Space Explorer** | Your **whole Mac** as interactive bubbles, folder by folder: system volume, data volume, swap, Preboot… Drill down, spot what's heavy, remove it. |
| 📄 | **Large Files** | Big files sleeping in your home folder, grouped by type: installers, videos, archives… |
| 🧩 | **Uninstaller** | Removes an app **and** everything it left in `~/Library`: preferences, caches, containers, saved state, launch agents… |
| 🌍 | **English & French** | Follows your system language, or pick one in Settings. |

<div align="center">
<table>
  <tr>
    <td><img src="docs/images/space-explorer.png" alt="Space Explorer" /></td>
    <td><img src="docs/images/smart-results.png" alt="Smart Scan results" /></td>
  </tr>
  <tr>
    <td align="center"><b>Space Explorer</b>: the whole disk, as bubbles</td>
    <td align="center"><b>Smart Scan</b>: everything at a glance</td>
  </tr>
  <tr>
    <td><img src="docs/images/caches.png" alt="Review details" /></td>
    <td><img src="docs/images/uninstaller.png" alt="Uninstaller" /></td>
  </tr>
  <tr>
    <td align="center"><b>Review details</b>: you decide, item by item</td>
    <td align="center"><b>Uninstaller</b>: the app and its leftovers</td>
  </tr>
</table>
</div>

## 🛡️ Safety first

A cleaner you can't trust is worse than no cleaner. Balai is built around that:

- **Nothing is deleted without confirmation.** You review every item, then choose: **Move to Trash** (recoverable, the default) or **Delete permanently**.
- **Risky items are flagged *Review*** and never pre-selected: Apple system caches, Xcode archives, large files, shared containers, leftovers matched only by app name…
- **One safety guard checks every path** ([`SafetyGuard.swift`](Sources/Balai/Core/SafetyGuard.swift)) right before deletion, whatever module proposed it:
  - only your home folder and third-party `.app` bundles in `/Applications` can be removed;
  - **always refused:** system folders, Apple apps, Keychains, `~/.ssh`, `~/.gnupg`, accounts, contacts, calendars, Safari data, Mail, Messages, iCloud Drive and cloud storage;
  - paths are normalized (`..`, symlinked parents) and compared case-insensitively, like the file system does.
- **The Space Explorer shows everything but locks what it shouldn't touch** 🔒.
- **No network, no telemetry, no account, no background process.**

> [!NOTE]
> Found a way to make Balai delete something it shouldn't? Please report it privately: see [SECURITY.md](SECURITY.md).

## 📦 Installation

**Requirements:** macOS 13 Ventura or later · Apple Silicon or Intel

### Homebrew (recommended)

```bash
brew install --cask root-lr/balai/balai
```

Homebrew takes care of the macOS security warning for you. Update with `brew upgrade --cask balai`.

### Manual download

<a href="https://github.com/root-lr/Balai/releases/latest/download/Balai.dmg"><img src="https://img.shields.io/badge/Download_for_macOS-Balai.dmg-FF5FA2?style=for-the-badge&logo=apple&logoColor=white" alt="Download for macOS" height="40" /></a>

Open the `.dmg` and drag **Balai** into **Applications**.

> [!IMPORTANT]
> Balai isn't notarized yet (that requires a paid Apple Developer account), so macOS blocks the first launch. Run this once:
>
> ```bash
> xattr -dr com.apple.quarantine /Applications/Balai.app
> ```
>
> Or open **System Settings › Privacy & Security** and click **Open Anyway**.

> [!TIP]
> Grant **Full Disk Access** (System Settings › Privacy & Security › Full Disk Access), then relaunch Balai. Without it, some folders stay invisible to the scans.

## 🛠️ Build from source

Requires Xcode 15 or later.

```bash
git clone https://github.com/root-lr/Balai.git
cd Balai
swift run                   # run in development
swift test                  # run the tests
./scripts/build-app.sh      # build Balai.app + Balai.dmg in ./build
./scripts/make-icon.sh      # regenerate the app icon
```

You can also open `Package.swift` in Xcode.

<details>
<summary><b>Project structure</b></summary>

```
Sources/Balai/
├── Core/          # models, SafetyGuard, Deleter, permissions, localization
├── Modules/       # one scanner per module, the uninstaller, the disk explorer
├── ViewModels/    # app state (SwiftUI, @MainActor)
└── Views/         # interface: theme, components, one view per screen
Tests/BalaiTests/  # SafetyGuard and leftover-matching tests
packaging/         # Homebrew cask
scripts/           # build, icon
```

Adding a cleanup module = writing a type that conforms to `Scanner` and returns `[CleanupItem]`. Confirmation, deletion and UI come for free.

</details>

## 🗺️ Roadmap

- [x] Smart Scan, caches, developer files, large files, uninstaller
- [x] Space Explorer for the whole disk
- [x] English & French
- [x] Homebrew Cask
- [ ] Notarized builds
- [ ] Orphaned leftovers (files from apps already deleted)
- [ ] Duplicate finder
- [ ] Docker images & iOS simulators cleanup
- [ ] Menu bar widget with free space
- [ ] More languages

Ideas welcome: [open a feature request](https://github.com/root-lr/Balai/issues/new/choose).

## 🤝 Contributing

Balai is **open to contributions**, from typo fixes to new cleanup modules. Start with [CONTRIBUTING.md](CONTRIBUTING.md), then look for issues labeled [`good first issue`](https://github.com/root-lr/Balai/labels/good%20first%20issue).

Proposing a new cleanup location? Tell us **why it's safe to delete** and **whether it regenerates on its own**. That's the one rule.

## ⭐ Star history

<a href="https://star-history.com/#root-lr/Balai&Date">
  <img src="https://api.star-history.com/svg?repos=root-lr/Balai&type=Date" alt="Star history" width="600" />
</a>

## 📄 License

[MIT](LICENSE). Free to use, modify and share.

<div align="center">
<br />
<sub>Made with SwiftUI · If Balai saved you some gigabytes, a ⭐ helps others find it.</sub>
</div>
