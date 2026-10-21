import Foundation

/// Niveau de risque d'un élément à supprimer.
enum Risk: Hashable, Sendable {
    /// Régénéré automatiquement par le système ou l'app (caches, builds…).
    case safe
    /// Peut contenir des données utiles : à vérifier avant de supprimer.
    case review
}

/// Comment un élément est supprimé.
enum Removal: Hashable, Sendable {
    /// Fichier ou dossier : Corbeille ou suppression définitive, après contrôle par `SafetyGuard`.
    case file
    /// Commande de l'outil qui gère l'élément (`docker rm`, `xcrun simctl delete`…). Toujours définitif.
    /// `order` fixe l'ordre d'exécution : un conteneur doit partir avant son image.
    case tool(String, [String], order: Int = 0)
    /// Agent de lancement : déchargé avec `launchctl`, puis son fichier est supprimé comme `.file`.
    case launchAgent(label: String)

    var isFile: Bool {
        switch self {
        case .file, .launchAgent: return true
        case .tool: return false
        }
    }

    var order: Int {
        if case .tool(_, _, let order) = self { return order }
        return 0
    }
}

/// Un élément proposé au nettoyage : fichier, dossier, ou objet géré par un outil (image Docker…).
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
    var removal: Removal = .file
    /// Symbole SF affiché à la place de l'icône du Finder, pour ce qui n'est pas un fichier.
    var symbol: String?
}

/// Les modules affichés dans la barre latérale.
enum CleanupCategory: String, CaseIterable, Identifiable, Hashable {
    case caches
    case devFiles
    case largeFiles
    case uninstaller
    case spaceLens
    case containers
    case aiModels
    case virtualMachines
    case devices
    case duplicates
    case orphans
    case startupItems

    var id: String { rawValue }

    var title: String {
        switch self {
        case .caches: return L("Caches et logs", "Caches & Logs")
        case .devFiles: return L("Fichiers développeur", "Developer Files")
        case .largeFiles: return L("Gros fichiers", "Large Files")
        case .uninstaller: return L("Désinstalleur", "Uninstaller")
        case .spaceLens: return L("Explorateur d'espace", "Space Explorer")
        case .containers: return L("Conteneurs", "Containers")
        case .aiModels: return L("Modèles d'IA", "AI Models")
        case .virtualMachines: return L("Machines virtuelles", "Virtual Machines")
        case .devices: return L("iPhone et iPad", "iPhone & iPad")
        case .duplicates: return L("Doublons", "Duplicates")
        case .orphans: return L("Restes d'apps", "App Leftovers")
        case .startupItems: return L("Démarrage", "Startup Items")
        }
    }

    var subtitle: String {
        switch self {
        case .caches: return L("Caches d'applications, journaux et rapports de plantage", "App caches, logs and crash reports")
        case .devFiles: return L("Xcode, simulateurs, caches npm/Gradle/Cargo et node_modules oubliés", "Xcode, simulators, npm/Gradle/Cargo caches and forgotten node_modules")
        case .largeFiles: return L("Les fichiers volumineux qui dorment dans votre dossier personnel", "Big files sleeping in your home folder")
        case .uninstaller: return L("Supprime une app et tous les fichiers qu'elle a laissés derrière elle", "Removes an app and everything it left behind")
        case .spaceLens: return L("Tout votre Mac, dossier par dossier : voyez ce qui prend de la place", "Your whole Mac, folder by folder: see what takes up space")
        case .containers: return L("Images, conteneurs, volumes et cache de build Docker, clusters Kubernetes locaux", "Docker images, containers, volumes and build cache, local Kubernetes clusters")
        case .aiModels: return L("Modèles téléchargés par Ollama, LM Studio, Hugging Face et les autres outils d'IA locaux", "Models downloaded by Ollama, LM Studio, Hugging Face and other local AI tools")
        case .virtualMachines: return L("UTM, Parallels, VMware, VirtualBox, émulateurs Android, Vagrant, Lima et Colima", "UTM, Parallels, VMware, VirtualBox, Android emulators, Vagrant, Lima and Colima")
        case .devices: return L("Anciennes sauvegardes d'appareils et mises à jour iOS téléchargées", "Old device backups and downloaded iOS updates")
        case .duplicates: return L("Fichiers identiques présents en plusieurs exemplaires dans votre dossier personnel", "Identical files stored more than once in your home folder")
        case .orphans: return L("Caches, préférences et données laissés par des apps déjà supprimées", "Caches, preferences and data left behind by apps you already deleted")
        case .startupItems: return L("Agents lancés à l'ouverture de votre session, dont ceux d'apps disparues", "Agents launched when you log in, including those of apps that are gone")
        }
    }

    var symbol: String {
        switch self {
        case .caches: return "archivebox"
        case .devFiles: return "hammer"
        case .largeFiles: return "doc.zipper"
        case .uninstaller: return "xmark.app"
        case .spaceLens: return "circle.hexagongrid"
        case .containers: return "shippingbox"
        case .aiModels: return "brain"
        case .virtualMachines: return "desktopcomputer"
        case .devices: return "iphone"
        case .duplicates: return "doc.on.doc"
        case .orphans: return "puzzlepiece"
        case .startupItems: return "power"
        }
    }

    /// Faux pour les modules où l'on compte des éléments plutôt que des octets.
    var measuresSpace: Bool {
        self != .startupItems
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
    /// Nom affiché quand l'élément n'est pas un fichier (image Docker, runtime…).
    var name: String?
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
