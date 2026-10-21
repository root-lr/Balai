import Foundation

/// Un module d'analyse. `scan` s'exécute hors du thread principal et doit
/// vérifier régulièrement `Task.isCancelled`.
protocol Scanner: Sendable {
    func scan(progress: @escaping @Sendable (String) -> Void) async -> [CleanupItem]
}
