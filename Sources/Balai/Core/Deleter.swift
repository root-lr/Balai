import Foundation

enum Deleter {
    /// Supprime les éléments : les fichiers vont à la Corbeille (ou sont supprimés) après vérification
    /// par `SafetyGuard` ; les objets gérés par un outil (Docker, simulateurs…) passent par cet outil.
    /// S'exécute hors du thread principal.
    static func delete(_ items: [CleanupItem], mode: DeletionMode) async -> DeletionReport {
        var report = DeletionReport(mode: mode)
        // Ordre imposé par les outils (un conteneur avant son image), sinon l'ordre de la sélection.
        let ordered = items.enumerated()
            .sorted { ($0.element.removal.order, $0.offset) < ($1.element.removal.order, $1.offset) }
            .map(\.element)

        for item in ordered {
            switch item.removal {
            case .file:
                deleteFile(item, mode: mode, report: &report)
            case .launchAgent(let label):
                // Décharger l'agent avant de supprimer son fichier ; s'il ne tournait pas, l'échec est sans importance.
                _ = await ExternalTool.run("launchctl", ["bootout", "gui/\(getuid())/\(label)"], timeout: 20)
                deleteFile(item, mode: mode, report: &report)
            case .tool(let name, let arguments, _):
                guard let output = await ExternalTool.run(name, arguments, timeout: 600) else {
                    report.failures.append(DeletionFailure(
                        url: item.url, reason: L("Outil introuvable : \(name)", "Tool not found: \(name)"), name: item.name))
                    continue
                }
                if output.succeeded {
                    report.deletedCount += 1
                    report.bytes += item.size
                } else {
                    report.failures.append(DeletionFailure(url: item.url, reason: output.errorSummary, name: item.name))
                }
            }
        }
        return report
    }

    private static func deleteFile(_ item: CleanupItem, mode: DeletionMode, report: inout DeletionReport) {
        let fm = FileManager.default
        if case .denied(let reason) = SafetyGuard.verdict(for: item.url) {
            report.failures.append(DeletionFailure(url: item.url, reason: reason))
            return
        }

        // lstat : ne suit pas les liens. Si l'élément a déjà disparu (supprimé avec
        // son dossier parent, par exemple), on passe simplement au suivant.
        guard (try? fm.attributesOfItem(atPath: item.url.path)) != nil else { return }

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
}
