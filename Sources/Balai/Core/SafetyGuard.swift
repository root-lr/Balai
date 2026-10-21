import Foundation

/// Dernier rempart avant toute suppression.
///
/// Chaque chemin est vérifié ici juste avant d'être supprimé, quel que soit le module
/// qui l'a proposé. Les règles sont volontairement strictes : en cas de doute, on refuse.
enum SafetyGuard {
    enum Verdict: Equatable {
        case allowed
        case denied(String)
    }

    /// Les volumes macOS ignorent la casse par défaut : « ~/library/keychains » est le même dossier
    /// que « ~/Library/Keychains ». Toutes les comparaisons se font donc sur des chemins en minuscules.
    private static func key(_ path: String) -> String { path.lowercased() }

    private static let homePath = key(normalize(Paths.home))

    /// Dossiers qui ne doivent jamais être supprimés eux-mêmes (leur contenu peut l'être).
    private static let protectedExact: Set<String> = {
        let relative = [
            "", "Library", "Library/Caches", "Library/Logs", "Library/Application Support",
            "Library/Preferences", "Library/Containers", "Library/Group Containers",
            "Library/Developer", "Library/Developer/Xcode", "Library/LaunchAgents",
            "Applications", "Desktop", "Documents", "Downloads", "Movies", "Music",
            "Pictures", "Public", ".Trash",
        ]
        var set = Set(relative.map { key(normalize(Paths.home.appendingPathComponent($0))) })
        set.insert("/")
        set.insert("/applications")
        return set
    }()

    /// Zones du dossier personnel où l'on ne touche jamais à rien : identifiants, données personnelles
    /// et contenus synchronisés.
    private static var forbiddenPrefixes: [(path: String, reason: String)] {
        let zones: [(URL, String)] = [
            (Paths.lib("Keychains"), L("Trousseaux de clés", "Keychains")),
            (Paths.inHome(".ssh"), L("Clés SSH", "SSH keys")),
            (Paths.inHome(".gnupg"), L("Clés GPG", "GPG keys")),
            (Paths.lib("Accounts"), L("Comptes", "Accounts")),
            (Paths.lib("Application Support", "com.apple.TCC"), L("Autorisations de confidentialité", "Privacy permissions")),
            (Paths.lib("Application Support", "AddressBook"), L("Contacts", "Contacts")),
            (Paths.lib("Calendars"), L("Calendriers", "Calendars")),
            (Paths.lib("Safari"), L("Historique et favoris Safari", "Safari history and bookmarks")),
            (Paths.lib("Mobile Documents"), "iCloud Drive"),
            (Paths.lib("CloudStorage"), L("Stockage cloud (Dropbox, Google Drive…)", "Cloud storage (Dropbox, Google Drive…)")),
            (Paths.lib("Mail"), L("Boîtes mail", "Mailboxes")),
            (Paths.lib("Messages"), "Messages"),
        ]
        return zones.map { (key(normalize($0.0)), $0.1) }
    }

    /// Chemin absolu, sans « .. » ni lien symbolique dans les dossiers parents.
    /// Le dernier composant n'est pas résolu : un lien symbolique est supprimé, pas sa cible.
    static func normalize(_ url: URL) -> String {
        let standardized = url.standardizedFileURL
        let parent = standardized.deletingLastPathComponent().resolvingSymlinksInPath()
        var path = parent.appendingPathComponent(standardized.lastPathComponent).path
        while path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        return path
    }

    static func verdict(for url: URL) -> Verdict {
        let path = key(normalize(url))

        if protectedExact.contains(path) {
            return .denied(L("Dossier protégé", "Protected folder"))
        }
        for forbidden in forbiddenPrefixes where path == forbidden.path || path.hasPrefix(forbidden.path + "/") {
            return .denied(L("Emplacement protégé : \(forbidden.reason)", "Protected location: \(forbidden.reason)"))
        }

        if path.hasPrefix(homePath + "/") {
            return .allowed
        }

        if path.hasPrefix("/applications/") {
            let relative = path.dropFirst("/applications/".count)
            let depth = relative.split(separator: "/").count
            guard path.hasSuffix(".app"), depth <= 2 else {
                return .denied(L("Seules les apps (.app) peuvent être supprimées dans /Applications", "Only apps (.app) can be removed from /Applications"))
            }
            if let bundleID = Bundle(url: url)?.bundleIdentifier, bundleID.hasPrefix("com.apple.") {
                return .denied(L("Les apps Apple sont protégées", "Apple apps are protected"))
            }
            if key(normalize(Bundle.main.bundleURL)) == path {
                return .denied(L("Balai ne peut pas se supprimer lui-même", "Balai cannot remove itself"))
            }
            return .allowed
        }

        return .denied(L("Hors des emplacements autorisés", "Outside allowed locations"))
    }
}
