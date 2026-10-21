import Foundation

/// Un module d'analyse. `scan` s'exécute hors du thread principal et doit
/// vérifier régulièrement `Task.isCancelled`.
protocol Scanner: Sendable {
    func scan(progress: @escaping @Sendable (String) -> Void) async -> [CleanupItem]
    /// Raison pour laquelle le module ne peut rien analyser (outil absent, moteur arrêté…), ou `nil`.
    func unavailableReason() async -> String?
}

extension Scanner {
    func unavailableReason() async -> String? { nil }
}
