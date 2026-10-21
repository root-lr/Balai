import AppKit

struct InstalledApp: Identifiable, Hashable, Sendable {
    var id: URL { url }
    let url: URL
    let name: String
    let bundleID: String?
    let version: String?
    var size: Int64?
}

/// Règles de correspondance entre un nom de fichier et une app.
enum LeftoverRule: Sendable {
    /// Nom exact : identifiant du bundle ou nom de l'app.
    case exactName
    /// Identifiant du bundle, éventuellement suivi d'un suffixe (com.foo.app.helper).
    case bundlePrefix
    /// bundlePrefix ou nom exact de l'app.
    case bundlePrefixOrName
    /// Fichier de préférences : com.foo.app.plist ou com.foo.app.XXXX.plist.
    case plist
    /// Conteneur de groupe : TEAMID.com.foo.app
    case groupSuffix
    /// com.foo.app.savedState
    case savedState
    /// com.foo.app.binarycookies
    case cookies
}

enum LeftoverMatcher {
    static func matches(_ fileName: String, rule: LeftoverRule, bundleID: String, appName: String) -> Bool {
        let name = fileName.lowercased()
        let bid = bundleID.lowercased()
        let app = appName.lowercased()
        // Un identifiant trop court (« com.vendor ») ferait correspondre toutes les apps de l'éditeur.
        let prefixIsSafe = bid.split(separator: ".").count >= 3
        let nameIsSafe = app.count >= 3

        switch rule {
        case .exactName:
            return name == bid || (nameIsSafe && name == app)
        case .bundlePrefix:
            return name == bid || (prefixIsSafe && name.hasPrefix(bid + "."))
        case .bundlePrefixOrName:
            return matches(fileName, rule: .bundlePrefix, bundleID: bundleID, appName: appName)
                || (nameIsSafe && name == app)
        case .plist:
            return name == bid + ".plist"
                || (prefixIsSafe && name.hasPrefix(bid + ".") && name.hasSuffix(".plist"))
        case .groupSuffix:
            return prefixIsSafe && name.hasSuffix("." + bid)
        case .savedState:
            return name == bid + ".savedstate"
        case .cookies:
            return name == bid + ".binarycookies"
        }
    }
}

enum AppUninstaller {
    private struct Location {
        let path: [String]          // relatif à ~/Library
        let group: String
        let rule: LeftoverRule
        let risk: Risk
        let preselected: Bool
        let detail: String?
    }

    private static var locations: [Location] { [
        Location(path: ["Application Support"], group: L("Données de l'app", "App Data"), rule: .exactName,
                 risk: .review, preselected: true, detail: L("Peut contenir vos réglages et données", "May contain your settings and data")),
        Location(path: ["Containers"], group: L("Données de l'app", "App Data"), rule: .bundlePrefix,
                 risk: .review, preselected: true, detail: L("Conteneur sandbox de l'app", "The app's sandbox container")),
        Location(path: ["Group Containers"], group: L("Données de l'app", "App Data"), rule: .groupSuffix,
                 risk: .review, preselected: false, detail: L("Peut être partagé avec d'autres apps du même éditeur", "May be shared with other apps from the same developer")),
        Location(path: ["Caches"], group: "Caches", rule: .bundlePrefixOrName,
                 risk: .safe, preselected: true, detail: nil),
        Location(path: ["HTTPStorages"], group: "Caches", rule: .bundlePrefix,
                 risk: .safe, preselected: true, detail: nil),
        Location(path: ["WebKit"], group: "Caches", rule: .bundlePrefix,
                 risk: .safe, preselected: true, detail: nil),
        Location(path: ["Preferences"], group: L("Préférences", "Preferences"), rule: .plist,
                 risk: .safe, preselected: true, detail: nil),
        Location(path: ["Preferences", "ByHost"], group: L("Préférences", "Preferences"), rule: .plist,
                 risk: .safe, preselected: true, detail: nil),
        Location(path: ["Saved Application State"], group: L("Autres fichiers", "Other Files"), rule: .savedState,
                 risk: .safe, preselected: true, detail: L("État des fenêtres", "Window state")),
        Location(path: ["Cookies"], group: L("Autres fichiers", "Other Files"), rule: .cookies,
                 risk: .safe, preselected: true, detail: nil),
        Location(path: ["Logs"], group: L("Autres fichiers", "Other Files"), rule: .exactName,
                 risk: .safe, preselected: true, detail: nil),
        Location(path: ["LaunchAgents"], group: L("Autres fichiers", "Other Files"), rule: .plist,
                 risk: .safe, preselected: true, detail: L("Lancement automatique à l'ouverture de session", "Launches automatically at login")),
        Location(path: ["Application Scripts"], group: L("Autres fichiers", "Other Files"), rule: .bundlePrefix,
                 risk: .safe, preselected: true, detail: nil),
    ] }

    /// Apps de /Applications (et un niveau de sous-dossiers) et de ~/Applications,
    /// hors apps Apple et hors Balai.
    static func installedApps() async -> [InstalledApp] {
        let roots = [URL(fileURLWithPath: "/Applications"), Paths.inHome("Applications")]
        var bundles: [URL] = []
        for root in roots {
            for child in FileScanning.children(of: root) {
                if child.pathExtension == "app" {
                    bundles.append(child)
                } else if FileScanning.isDirectory(child), child.lastPathComponent != "Utilities" {
                    bundles += FileScanning.children(of: child).filter { $0.pathExtension == "app" }
                }
            }
        }

        let ownID = Bundle.main.bundleIdentifier
        var apps: [InstalledApp] = []
        for url in bundles {
            if Task.isCancelled { return [] }
            let bundle = Bundle(url: url)
            let bundleID = bundle?.bundleIdentifier
            if let bundleID, bundleID.hasPrefix("com.apple.") || bundleID == ownID { continue }
            let displayName = FileManager.default.displayName(atPath: url.path)
            apps.append(InstalledApp(
                url: url,
                name: displayName.hasSuffix(".app") ? String(displayName.dropLast(4)) : displayName,
                bundleID: bundleID,
                version: bundle?.infoDictionary?["CFBundleShortVersionString"] as? String,
                size: nil
            ))
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func size(of app: InstalledApp) async -> Int64 {
        FileScanning.allocatedSize(of: app.url)
    }

    /// L'app elle-même suivie de tous ses fichiers résiduels.
    static func leftovers(for app: InstalledApp) async -> [CleanupItem] {
        var items: [CleanupItem] = []
        if let bundle = FileScanning.makeItem(
            url: app.url, name: app.name, detail: Format.abbreviate(app.url),
            group: "Application", risk: .safe, preselected: true
        ) {
            items.append(bundle)
        }

        guard let bundleID = app.bundleID else { return items }
        var seen = Set<String>()

        for location in locations {
            if Task.isCancelled { return [] }
            let dir = location.path.reduce(Paths.library) { $0.appendingPathComponent($1) }
            for child in FileScanning.children(of: dir) {
                guard LeftoverMatcher.matches(
                    child.lastPathComponent, rule: location.rule, bundleID: bundleID, appName: app.name
                ), seen.insert(child.path).inserted else { continue }

                // Trouvé grâce au seul nom de l'app (pas son identifiant) : peut appartenir à une app
                // homonyme, donc à vérifier et jamais pré-coché.
                let matchesBundleID = LeftoverMatcher.matches(
                    child.lastPathComponent, rule: location.rule, bundleID: bundleID, appName: ""
                )
                if let item = FileScanning.makeItem(
                    url: child,
                    name: child.lastPathComponent,
                    detail: location.detail ?? Format.abbreviate(child.deletingLastPathComponent()),
                    group: location.group,
                    risk: matchesBundleID ? location.risk : .review,
                    preselected: matchesBundleID && location.preselected
                ) {
                    items.append(item)
                }
            }
        }
        return items
    }

    static func isRunning(_ app: InstalledApp) -> Bool {
        guard let bundleID = app.bundleID else { return false }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    static func quit(_ app: InstalledApp) {
        guard let bundleID = app.bundleID else { return }
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).forEach { $0.terminate() }
    }
}
