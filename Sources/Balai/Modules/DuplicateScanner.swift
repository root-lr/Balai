import Foundation
import CryptoKit

/// Fichiers identiques octet pour octet dans le dossier personnel.
/// Pour chaque série, le plus ancien est gardé comme original et n'est jamais proposé :
/// cocher tout un groupe ne peut donc jamais supprimer toutes les copies.
struct DuplicateScanner: Scanner {
    /// En dessous, le gain ne vaut pas le temps de comparaison.
    private let minimumSize: Int64 = 1_000_000

    /// Dossiers de dépendances : leurs copies sont normales et relèvent des fichiers développeur.
    private static let skippedFolders: Set<String> = [
        "node_modules", "Pods", "vendor", "venv", "DerivedData", "site-packages", "Carthage",
    ]

    private struct Candidate {
        let url: URL
        let allocatedSize: Int64
        let created: Date
        let modified: Date?
        /// Identique pour deux clones APFS : ils partagent leurs blocs, supprimer l'un ne libère rien.
        let contentIdentifier: Int64?
    }

    func scan(progress: @escaping @Sendable (String) -> Void) async -> [CleanupItem] {
        progress(L("Recherche des fichiers…", "Looking for files…"))
        let bySize = collectCandidates(progress: progress)
        if Task.isCancelled { return [] }

        var duplicateSets: [[Candidate]] = []
        var compared = 0
        for (_, group) in bySize {
            if Task.isCancelled { return [] }
            // Les clones APFS ne prennent pas de place en plus : on n'en garde qu'un.
            var seenClones = Set<Int64>()
            let files = group.filter { $0.contentIdentifier.map { seenClones.insert($0).inserted } ?? true }
            guard files.count > 1 else { continue }

            compared += files.count
            progress(L("Comparaison de \(compared) fichiers…", "Comparing \(compared) files…"))
            // Empreinte rapide (début du fichier), puis complète uniquement pour ce qui se ressemble encore.
            for quickGroup in Dictionary(grouping: files, by: { Self.hash($0.url, limit: 65_536) ?? UUID().uuidString }).values
            where quickGroup.count > 1 {
                for fullGroup in Dictionary(grouping: quickGroup, by: { Self.hash($0.url, limit: nil) ?? UUID().uuidString }).values
                where fullGroup.count > 1 {
                    duplicateSets.append(fullGroup.sorted { $0.created < $1.created })
                }
            }
        }

        // Les séries qui libèrent le plus d'espace d'abord.
        duplicateSets.sort { $0.dropFirst().reduce(0) { $0 + $1.allocatedSize } > $1.dropFirst().reduce(0) { $0 + $1.allocatedSize } }

        return duplicateSets.flatMap { set -> [CleanupItem] in
            let original = set[0]
            let group = L("\(original.url.lastPathComponent) · original dans \(Format.abbreviate(original.url.deletingLastPathComponent()))",
                          "\(original.url.lastPathComponent) · original in \(Format.abbreviate(original.url.deletingLastPathComponent()))")
            return set.dropFirst().map { copy in
                CleanupItem(url: copy.url, name: copy.url.lastPathComponent,
                            detail: Format.abbreviate(copy.url.deletingLastPathComponent()),
                            group: group, size: copy.allocatedSize, modified: copy.modified,
                            risk: .review, preselected: false)
            }
        }
    }

    /// Fichiers du dossier personnel (hors Library, apps, fichiers cachés et intérieur des paquets), par taille exacte.
    private func collectCandidates(progress: @escaping @Sendable (String) -> Void) -> [Int64: [Candidate]] {
        let keys: [URLResourceKey] = [
            .isRegularFileKey, .isDirectoryKey, .isPackageKey, .fileSizeKey, .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey, .creationDateKey, .contentModificationDateKey, .fileContentIdentifierKey,
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: Paths.home, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, _ in true }
        ) else { return [:] }

        var bySize: [Int64: [Candidate]] = [:]
        for case let url as URL in enumerator {
            if Task.isCancelled { return [:] }
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isDirectory == true {
                if (enumerator.level == 1 && ["Library", "Applications"].contains(url.lastPathComponent))
                    || Self.skippedFolders.contains(url.lastPathComponent) {
                    enumerator.skipDescendants()
                } else if enumerator.level <= 2 {
                    progress(L("Analyse de \(Format.abbreviate(url))…", "Scanning \(Format.abbreviate(url))…"))
                }
                continue
            }
            guard values.isRegularFile == true, let size = values.fileSize, Int64(size) >= minimumSize else { continue }
            bySize[Int64(size), default: []].append(Candidate(
                url: url,
                allocatedSize: Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? size),
                created: values.creationDate ?? .distantPast,
                modified: values.contentModificationDate,
                contentIdentifier: values.fileContentIdentifier))
        }
        return bySize.filter { $0.value.count > 1 }
    }

    /// SHA-256 du fichier, ou de ses `limit` premiers octets.
    private static func hash(_ url: URL, limit: Int?) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        var remaining = limit ?? Int.max
        while remaining > 0 {
            if Task.isCancelled { return nil }
            let chunk = (try? handle.read(upToCount: min(1_048_576, remaining))) ?? nil
            guard let chunk, !chunk.isEmpty else { break }
            hasher.update(data: chunk)
            remaining -= chunk.count
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
