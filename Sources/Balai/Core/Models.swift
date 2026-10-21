import Foundation

/// Niveau de risque d'un élément à supprimer.
enum Risk: Hashable, Sendable {
    /// Régénéré automatiquement par le système ou l'app (caches, builds…).
    case safe
    /// Peut contenir des données utiles : à vérifier avant de supprimer.
    case review
}

/// Un fichier ou dossier proposé au nettoyage.
struct CleanupItem: Identifiable, Hashable, Sendable {
    var id: URL { url }
    let url: URL
    let name: String
    let detail: String?
    /// Section dans laquelle l'élément est affiché.
    let group: String
    /// Taille réellement occupée sur le disque, en octets.
    let size: Int64
    let modified: Date?
    let risk: Risk
    /// Coché par défaut après l'analyse.
    let preselected: Bool
}

/// Les modules affichés dans la barre latérale.
enum CleanupCategory: String, CaseIterable, Identifiable, Hashable {
    case caches
    case devFiles
    case largeFiles
    case uninstaller
    case spaceLens

    var id: String { rawValue }

    var title: String {
        switch self {
        case .caches: return L("Caches et logs", "Caches & Logs")
        case .devFiles: return L("Fichiers développeur", "Developer Files")
        case .largeFiles: return L("Gros fichiers", "Large Files")
        case .uninstaller: return L("Désinstalleur", "Uninstaller")
        case .spaceLens: return L("Explorateur d'espace", "Space Explorer")
        }
    }

    var subtitle: String {
        switch self {
        case .caches: return L("Caches d'applications, journaux et rapports de plantage", "App caches, logs and crash reports")
        case .devFiles: return L("Xcode, simulateurs, caches npm/Gradle/Cargo et node_modules oubliés", "Xcode, simulators, npm/Gradle/Cargo caches and forgotten node_modules")
        case .largeFiles: return L("Les fichiers volumineux qui dorment dans votre dossier personnel", "Big files sleeping in your home folder")
        case .uninstaller: return L("Supprime une app et tous les fichiers qu'elle a laissés derrière elle", "Removes an app and everything it left behind")
        case .spaceLens: return L("Tout votre Mac, dossier par dossier : voyez ce qui prend de la place", "Your whole Mac, folder by folder: see what takes up space")
        }
    }

    var symbol: String {
        switch self {
        case .caches: return "archivebox"
        case .devFiles: return "hammer"
        case .largeFiles: return "doc.zipper"
        case .uninstaller: return "xmark.app"
        case .spaceLens: return "circle.hexagongrid"
        }
    }
}

/// Mode de suppression choisi par l'utilisateur.
enum DeletionMode: String, CaseIterable, Identifiable, Sendable {
    case trash
    case permanent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .trash: return L("Mettre à la Corbeille", "Move to Trash")
        case .permanent: return L("Supprimer définitivement", "Delete Permanently")
        }
    }
}

struct DeletionFailure: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let reason: String
}

/// Bilan d'une opération de suppression.
struct DeletionReport: Sendable {
    let mode: DeletionMode
    var deletedCount = 0
    var bytes: Int64 = 0
    var failures: [DeletionFailure] = []
}

/// Clés des préférences (UserDefaults / @AppStorage).
enum Defaults {
    static let deletionMode = "deletionMode"
    static let largeFileThresholdMB = "largeFileThresholdMB"
    static let staleProjectDays = "staleProjectDays"
    static let language = "language"

    static var largeFileThresholdBytes: Int64 {
        let mb = UserDefaults.standard.object(forKey: largeFileThresholdMB) as? Int ?? 500
        return Int64(mb) * 1_000_000
    }

    static var staleDays: Int {
        UserDefaults.standard.object(forKey: staleProjectDays) as? Int ?? 30
    }
}

extension Notification.Name {
    /// Envoyée après chaque suppression, pour rafraîchir l'espace disque affiché.
    static let balaiDidDelete = Notification.Name("BalaiDidDelete")
}
