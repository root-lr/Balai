import AppKit

/// Caches d'applications (~/Library/Caches) et journaux (~/Library/Logs).
struct CacheScanner: Scanner {
    /// Caches Apple liés à iCloud ou à l'état du système : jamais pré-cochés.
    private static let sensitiveNames: Set<String> = [
        "CloudKit", "com.apple.bird", "com.apple.cloudd", "FamilyCircle", "com.apple.HomeKit",
        "com.apple.ap.adprivacyd", "com.apple.akd",
    ]

    func scan(progress: @escaping @Sendable (String) -> Void) async -> [CleanupItem] {
        let sources: [(dir: URL, group: String)] = [
            (Paths.lib("Caches"), L("Caches d'applications", "App Caches")),
            (Paths.lib("Logs"), L("Journaux et rapports de plantage", "Logs & Crash Reports")),
        ]
        let ownBundleID = Bundle.main.bundleIdentifier

        var result: [CleanupItem] = []
        for source in sources {
            var groupItems: [CleanupItem] = []
            for child in FileScanning.children(of: source.dir) {
                if Task.isCancelled { return [] }
                let name = child.lastPathComponent
                if name.hasPrefix(".") || name == ownBundleID { continue }

                progress(L("Analyse de \(name)…", "Scanning \(name)…"))
                let isApple = name.hasPrefix("com.apple.") || Self.sensitiveNames.contains(name)
                let detail: String
                if isApple {
                    detail = L("Cache système Apple, à vérifier avant suppression", "Apple system cache, review before removing")
                } else if name == "DiagnosticReports" {
                    detail = L("Rapports de plantage", "Crash reports")
                } else {
                    detail = Format.abbreviate(child)
                }

                if let item = FileScanning.makeItem(
                    url: child,
                    name: Self.displayName(for: name),
                    detail: detail,
                    group: source.group,
                    risk: isApple ? .review : .safe,
                    preselected: !isApple
                ) {
                    groupItems.append(item)
                }
            }
            result += groupItems.sorted { $0.size > $1.size }
        }
        return result
    }

    /// « com.spotify.client » → « Spotify » quand l'app est installée.
    static func displayName(for folderName: String) -> String {
        guard folderName.split(separator: ".").count >= 3,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: folderName)
        else { return folderName }
        let appName = FileManager.default.displayName(atPath: appURL.path)
        let clean = appName.hasSuffix(".app") ? String(appName.dropLast(4)) : appName
        return "\(clean) (\(folderName))"
    }
}
