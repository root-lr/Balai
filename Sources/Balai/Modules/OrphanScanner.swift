import AppKit

/// Fichiers de ~/Library nommés d'après une app (« com.editeur.app ») qui n'est plus installée.
/// Seul ce qui se régénère (caches, état des fenêtres…) est pré-coché, et jamais quand l'éditeur
/// a encore une app installée : ses outils annexes (mises à jour, assistants) peuvent s'en servir.
struct OrphanScanner: Scanner {
    private struct Location {
        let path: [String]
        let group: String
        /// Suffixe ajouté à l'identifiant dans le nom du fichier (« .plist », « .savedState »).
        let suffix: String
        let regenerates: Bool
    }

    private var locations: [Location] {
        [
            Location(path: ["Caches"], group: L("Caches", "Caches"), suffix: "", regenerates: true),
            Location(path: ["HTTPStorages"], group: L("Caches", "Caches"), suffix: "", regenerates: true),
            Location(path: ["WebKit"], group: L("Caches", "Caches"), suffix: "", regenerates: true),
            Location(path: ["Saved Application State"], group: L("État des fenêtres", "Window State"),
                     suffix: ".savedState", regenerates: true),
            Location(path: ["Preferences"], group: L("Préférences", "Preferences"), suffix: ".plist", regenerates: false),
            Location(path: ["Application Support"], group: L("Données d'apps", "App Data"), suffix: "", regenerates: false),
            Location(path: ["Containers"], group: L("Conteneurs d'apps", "App Containers"), suffix: "", regenerates: false),
        ]
    }

    func scan(progress: @escaping @Sendable (String) -> Void) async -> [CleanupItem] {
        progress(L("Inventaire des apps installées…", "Listing installed apps…"))
        let installed = Self.installedBundleIDs()
        let vendors = Set(installed.map(Self.vendor))

        var items: [CleanupItem] = []
        for location in locations {
            if Task.isCancelled { return [] }
            let dir = location.path.reduce(Paths.library) { $0.appendingPathComponent($1) }
            progress(L("Analyse de ~/Library/\(location.path.joined(separator: "/"))…",
                       "Scanning ~/Library/\(location.path.joined(separator: "/"))…"))

            var found: [CleanupItem] = []
            for child in FileScanning.children(of: dir) {
                let fileName = child.lastPathComponent
                guard fileName.hasSuffix(location.suffix) else { continue }
                let identifier = String(fileName.dropLast(location.suffix.count))
                guard Self.looksLikeBundleID(identifier), !Self.isInstalled(identifier, installed: installed) else { continue }

                let vendorStillHere = vendors.contains(Self.vendor(identifier))
                let detail = vendorStillHere
                    ? L("Aucune app correspondante, mais l'éditeur a encore une app installée",
                        "No matching app, but the developer still has an app installed")
                    : L("Aucune app installée ne correspond", "No installed app matches")
                if let item = FileScanning.makeItem(
                    url: child, name: identifier, detail: detail, group: location.group,
                    risk: location.regenerates && !vendorStillHere ? .safe : .review,
                    preselected: location.regenerates && !vendorStillHere
                ) {
                    found.append(item)
                }
            }
            items += found.sorted { $0.size > $1.size }
        }
        return items
    }

    /// « com.editeur.app » : au moins trois segments, le premier ressemblant à un domaine.
    private static func looksLikeBundleID(_ name: String) -> Bool {
        let parts = name.split(separator: ".")
        guard parts.count >= 3, let first = parts.first,
              (2...10).contains(first.count), first.allSatisfy({ $0.isLetter && $0.isLowercase })
        else { return false }
        let lowered = name.lowercased()
        // Composants du système qui ne sont pas des apps (impression…).
        let systemPrefixes = ["com.apple.", "group.", "org.cups."]
        return !systemPrefixes.contains { lowered.hasPrefix($0) }
    }

    /// Installée si une app connue a cet identifiant, en est le préfixe (« app.helper ») ou l'inverse.
    private static func isInstalled(_ identifier: String, installed: Set<String>) -> Bool {
        let id = identifier.lowercased()
        if installed.contains(id) { return true }
        if installed.contains(where: { id.hasPrefix($0 + ".") || $0.hasPrefix(id + ".") }) { return true }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) != nil
    }

    /// « com.editeur.app » → « com.editeur ».
    private static func vendor(_ identifier: String) -> String {
        identifier.lowercased().split(separator: ".").prefix(2).joined(separator: ".")
    }

    /// Identifiants des apps présentes dans les dossiers d'applications habituels (deux niveaux).
    private static func installedBundleIDs() -> Set<String> {
        let roots = [
            URL(fileURLWithPath: "/Applications"), Paths.inHome("Applications"),
            URL(fileURLWithPath: "/System/Applications"), URL(fileURLWithPath: "/System/Applications/Utilities"),
            URL(fileURLWithPath: "/Applications/Utilities"),
        ]
        var bundles: [URL] = []
        for root in roots {
            for child in FileScanning.children(of: root) {
                if child.pathExtension == "app" {
                    bundles.append(child)
                } else if FileScanning.isDirectory(child) {
                    bundles += FileScanning.children(of: child).filter { $0.pathExtension == "app" }
                }
            }
        }
        var ids = Set(bundles.compactMap { Bundle(url: $0)?.bundleIdentifier?.lowercased() })
        ids.formUnion(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier?.lowercased() })
        return ids
    }
}
