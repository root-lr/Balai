import Foundation

/// Langue de l'interface : celle du système par défaut, ou celle choisie dans les Réglages.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case french
    case english

    var id: String { rawValue }

    /// Nom affiché dans les Réglages (toujours dans sa propre langue).
    var label: String {
        switch self {
        case .system: return L("Langue du système", "System language")
        case .french: return "Français"
        case .english: return "English"
        }
    }

    /// Lue par les scanners en arrière-plan, modifiée depuis les Réglages : accès protégé par un verrou.
    private static let lock = NSLock()
    private static var current: AppLanguage = resolve()

    /// Langue réellement utilisée : jamais `.system`. Toute langue autre que le français donne l'anglais.
    static var resolved: AppLanguage {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    /// À appeler après un changement de langue dans les Réglages.
    static func refresh() {
        let language = resolve()
        lock.lock()
        current = language
        lock.unlock()
    }

    private static func resolve() -> AppLanguage {
        let stored = UserDefaults.standard.string(forKey: Defaults.language).flatMap(AppLanguage.init) ?? .system
        if stored != .system { return stored }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("fr") ? .french : .english
    }

    /// Locale pour les tailles et les dates, en gardant la région du système.
    var locale: Locale {
        let region = Locale.current.region?.identifier ?? (self == .french ? "FR" : "US")
        return Locale(identifier: (self == .french ? "fr_" : "en_") + region)
    }
}

/// Texte de l'interface dans la langue courante.
func L(_ french: String, _ english: String) -> String {
    AppLanguage.resolved == .french ? french : english
}
