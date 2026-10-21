import Foundation

/// Sauvegardes locales d'iPhone et d'iPad, et mises à jour iOS téléchargées par le Finder.
struct DeviceScanner: Scanner {
    private static let backups = Paths.lib("Application Support", "MobileSync", "Backup")

    func unavailableReason() async -> String? {
        // Le dossier des sauvegardes est protégé : sans l'accès complet au disque, il paraît vide.
        if FileScanning.exists(Self.backups),
           (try? FileManager.default.contentsOfDirectory(atPath: Self.backups.path)) == nil {
            return L("Accordez l'accès complet au disque pour voir les sauvegardes de vos appareils.",
                     "Grant Full Disk Access to see your device backups.")
        }
        return nil
    }

    func scan(progress: @escaping @Sendable (String) -> Void) async -> [CleanupItem] {
        progress(L("Lecture des sauvegardes…", "Reading backups…"))
        var items = backupItems()
        if Task.isCancelled { return [] }

        progress(L("Recherche des mises à jour iOS…", "Looking for iOS updates…"))
        for folder in ["iPhone Software Updates", "iPad Software Updates", "iPod Software Updates"] {
            items += FolderSource(
                root: Paths.lib("iTunes", folder), group: L("Mises à jour iOS téléchargées", "Downloaded iOS Updates"),
                extensions: ["ipsw"],
                detail: L("Retéléchargée automatiquement lors de la prochaine mise à jour",
                          "Downloaded again at the next update"),
                risk: .safe, preselected: true
            ).items()
        }
        return items
    }

    private func backupItems() -> [CleanupItem] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = AppLanguage.resolved.locale

        return FileScanning.children(of: Self.backups).compactMap { folder -> CleanupItem? in
            let info = NSDictionary(contentsOf: folder.appendingPathComponent("Info.plist")) as? [String: Any] ?? [:]
            let deviceName = info["Device Name"] as? String ?? info["Display Name"] as? String ?? folder.lastPathComponent
            let product = info["Product Name"] as? String ?? info["Product Type"] as? String ?? L("Appareil", "Device")
            let date = info["Last Backup Date"] as? Date ?? FileScanning.modificationDate(of: folder)
            let when = date.map { formatter.string(from: $0) } ?? "?"

            guard var item = FileScanning.makeItem(
                url: folder, name: deviceName,
                detail: L("\(product) · sauvegarde du \(when)", "\(product) · backed up \(when)"),
                group: L("Sauvegardes d'appareils", "Device Backups"), risk: .review, preselected: false)
            else { return nil }
            item.symbol = "iphone"
            return item
        }
        .sorted { ($0.modified ?? .distantPast) < ($1.modified ?? .distantPast) }
    }
}
