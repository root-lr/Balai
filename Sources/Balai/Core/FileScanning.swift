import Foundation

/// Emplacements utiles.
enum Paths {
    static let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
    static let library = home.appendingPathComponent("Library", isDirectory: true)

    static func lib(_ components: String...) -> URL {
        components.reduce(library) { $0.appendingPathComponent($1) }
    }

    static func inHome(_ components: String...) -> URL {
        components.reduce(home) { $0.appendingPathComponent($1) }
    }
}

/// Outils de parcours du disque, partagés par tous les modules.
enum FileScanning {
    static let keys: [URLResourceKey] = [
        .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .isPackageKey,
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .contentModificationDateKey,
    ]

    static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Contenu direct d'un dossier (vide si inaccessible).
    static func children(of dir: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: keys, options: []
        )) ?? []
    }

    static func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    /// Taille réellement occupée sur le disque (fichier ou dossier, sans suivre les liens symboliques).
    static func allocatedSize(of url: URL) -> Int64 {
        let keySet = Set(keys)
        guard let values = try? url.resourceValues(forKeys: keySet) else { return 0 }
        if values.isSymbolicLink == true { return 0 }
        if values.isDirectory != true {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let file as URL in enumerator {
            if Task.isCancelled { break }
            guard let v = try? file.resourceValues(forKeys: keySet), v.isRegularFile == true else { continue }
            total += Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
        }
        return total
    }

    /// Crée un élément à nettoyer, ou `nil` s'il est vide ou absent.
    static func makeItem(
        url: URL,
        name: String? = nil,
        detail: String? = nil,
        group: String,
        risk: Risk,
        preselected: Bool
    ) -> CleanupItem? {
        let size = allocatedSize(of: url)
        guard size > 0 else { return nil }
        return CleanupItem(
            url: url,
            name: name ?? url.lastPathComponent,
            detail: detail,
            group: group,
            size: size,
            modified: modificationDate(of: url),
            risk: risk,
            preselected: preselected
        )
    }
}

enum Format {
    /// « 1.063GB », « 242kB (virtual 866MB) », « 33.5MB » → octets. `base` : 1000 pour Docker, 1024 pour Homebrew.
    static func parseSize(_ text: String, base: Double = 1000) -> Int64 {
        let token = text.split(separator: " ").first.map(String.init) ?? text
        let units: [(suffix: String, power: Double)] = [
            ("KiB", 1), ("MiB", 2), ("GiB", 3), ("TiB", 4),
            ("kB", 1), ("KB", 1), ("MB", 2), ("GB", 3), ("TB", 4), ("B", 0),
        ]
        for unit in units where token.hasSuffix(unit.suffix) {
            let number = token.dropLast(unit.suffix.count).replacingOccurrences(of: ",", with: "")
            guard let value = Double(number) else { return 0 }
            let unitBase = unit.suffix.hasSuffix("iB") ? 1024 : base
            return Int64(value * pow(unitBase, unit.power))
        }
        return 0
    }

    static func bytes(_ value: Int64) -> String {
        value.formatted(.byteCount(style: .file, spellsOutZero: false).locale(AppLanguage.resolved.locale))
    }

    /// Remplace le dossier personnel par « ~ » pour l'affichage.
    static func abbreviate(_ url: URL) -> String {
        guard url.isFileURL else { return url.lastPathComponent }
        let path = url.path
        let home = Paths.home.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + String(path.dropFirst(home.count)) }
        return path
    }
}
