import Foundation

/// Fichiers volumineux du dossier personnel (hors ~/Library, fichiers cachés et paquets
/// comme la photothèque, qui ne sont jamais proposés).
struct LargeFileScanner: Scanner {
    let thresholdBytes: Int64

    enum Kind: Int, CaseIterable {
        case installer, video, archive, other

        var title: String {
            switch self {
            case .installer: return L("Installeurs et images disque", "Installers & Disk Images")
            case .video: return L("Vidéos", "Videos")
            case .archive: return "Archives"
            case .other: return L("Autres fichiers", "Other Files")
            }
        }

        init(fileExtension ext: String) {
            switch ext.lowercased() {
            case "dmg", "pkg", "iso", "img", "xip": self = .installer
            case "mov", "mp4", "m4v", "mkv", "avi", "webm", "mts": self = .video
            case "zip", "rar", "7z", "tar", "gz", "tgz", "xz", "bz2": self = .archive
            default: self = .other
            }
        }
    }

    func scan(progress: @escaping @Sendable (String) -> Void) async -> [CleanupItem] {
        collect(progress: progress)
    }

    /// Parcours synchrone : l'itérateur de `FileManager.DirectoryEnumerator` n'est pas utilisable en contexte async.
    private func collect(progress: @escaping @Sendable (String) -> Void) -> [CleanupItem] {
        let keys: [URLResourceKey] = [
            .isRegularFileKey, .isDirectoryKey, .isPackageKey,
            .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .contentModificationDateKey,
        ]
        let keySet = Set(keys)
        let skippedTopLevel: Set<String> = ["Library", "Applications"]

        guard let enumerator = FileManager.default.enumerator(
            at: Paths.home,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var found: [(kind: Kind, item: CleanupItem)] = []

        for case let url as URL in enumerator {
            if Task.isCancelled { return [] }
            guard let values = try? url.resourceValues(forKeys: keySet) else { continue }

            if values.isDirectory == true {
                if values.isPackage == true
                    || (enumerator.level == 1 && skippedTopLevel.contains(url.lastPathComponent)) {
                    enumerator.skipDescendants()
                } else if enumerator.level <= 2 {
                    progress(L("Analyse de \(Format.abbreviate(url))…", "Scanning \(Format.abbreviate(url))…"))
                }
                continue
            }

            guard values.isRegularFile == true else { continue }
            let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            guard size >= thresholdBytes else { continue }

            let kind = Kind(fileExtension: url.pathExtension)
            let item = CleanupItem(
                url: url,
                name: url.lastPathComponent,
                detail: Format.abbreviate(url.deletingLastPathComponent()),
                group: kind.title,
                size: size,
                modified: values.contentModificationDate,
                risk: .review,
                preselected: false
            )
            found.append((kind, item))
        }

        return found
            .sorted { $0.kind.rawValue != $1.kind.rawValue ? $0.kind.rawValue < $1.kind.rawValue : $0.item.size > $1.item.size }
            .map(\.item)
    }
}
