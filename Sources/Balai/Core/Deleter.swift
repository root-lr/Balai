import Foundation

enum Deleter {
    /// Supprime les éléments (Corbeille ou définitivement) après vérification par `SafetyGuard`.
    /// S'exécute hors du thread principal.
    static func delete(_ items: [CleanupItem], mode: DeletionMode) async -> DeletionReport {
        var report = DeletionReport(mode: mode)
        let fm = FileManager.default

        for item in items {
            if case .denied(let reason) = SafetyGuard.verdict(for: item.url) {
                report.failures.append(DeletionFailure(url: item.url, reason: reason))
                continue
            }

            // lstat : ne suit pas les liens. Si l'élément a déjà disparu (supprimé avec
            // son dossier parent, par exemple), on passe simplement au suivant.
            guard (try? fm.attributesOfItem(atPath: item.url.path)) != nil else { continue }

            do {
                switch mode {
                case .trash:
                    try fm.trashItem(at: item.url, resultingItemURL: nil)
                case .permanent:
                    try fm.removeItem(at: item.url)
                }
                report.deletedCount += 1
                report.bytes += item.size
            } catch {
                report.failures.append(DeletionFailure(url: item.url, reason: error.localizedDescription))
            }
        }
        return report
    }
}
