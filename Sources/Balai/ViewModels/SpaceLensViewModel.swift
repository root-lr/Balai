import SwiftUI

/// État de l'explorateur d'espace : analyse du disque, navigation et suppression.
@MainActor
final class SpaceLensViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case scanning(path: String, files: Int)
        case ready
        case deleting

        /// Étape, sans le détail de la progression : sert de clé d'animation.
        var stage: Int {
            switch self {
            case .idle: return 0
            case .scanning: return 1
            case .ready: return 2
            case .deleting: return 3
            }
        }
    }

    @Published private(set) var phase: Phase = .idle
    /// Chemin de navigation, de la racine au dossier affiché.
    @Published private(set) var path: [DiskNode] = []
    @Published private(set) var selection: [URL: DiskNode] = [:]
    @Published var report: DeletionReport?
    @Published private(set) var scanDuration: TimeInterval?

    private var task: Task<Void, Never>?

    var root: DiskNode? { path.first }
    var current: DiskNode? { path.last }

    // MARK: - Analyse

    func scan() {
        task?.cancel()
        report = nil
        selection = [:]
        phase = .scanning(path: "/", files: 0)
        let start = Date()

        let progress: @Sendable (String, Int) -> Void = { [weak self] path, files in
            Task { @MainActor in
                guard let self, case .scanning = self.phase else { return }
                self.phase = .scanning(path: path, files: files)
            }
        }

        task = Task { [weak self] in
            let root = await Task.detached(priority: .userInitiated) {
                await DiskExplorer.scan(progress: progress)
            }.value
            guard let self, !Task.isCancelled else { return }
            self.path = [root]
            #if DEBUG
            // BALAI_OPEN=Users/moi : ouvre ce dossier après l'analyse (captures d'écran).
            for name in (ProcessInfo.processInfo.environment["BALAI_OPEN"] ?? "").split(separator: "/") {
                if let child = self.current?.children.first(where: { $0.name == name }) { self.open(child) }
            }
            #endif
            self.scanDuration = Date().timeIntervalSince(start)
            self.phase = .ready
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = path.isEmpty ? .idle : .ready
    }

    // MARK: - Navigation

    func open(_ node: DiskNode) {
        guard node.canOpen else { return }
        path.append(node)
    }

    func goBack() {
        if path.count > 1 { path.removeLast() }
    }

    func go(to index: Int) {
        guard path.indices.contains(index) else { return }
        path.removeSubrange((index + 1)...)
    }

    // MARK: - Sélection

    func isDeletable(_ node: DiskNode) -> Bool {
        SafetyGuard.verdict(for: node.url) == .allowed
    }

    func binding(for node: DiskNode) -> Binding<Bool> {
        Binding(
            get: { [weak self] in self?.selection[node.url] != nil },
            set: { [weak self] isOn in self?.selection[node.url] = isOn ? node : nil }
        )
    }

    /// Sélection sans doublon : un élément dont un dossier parent est déjà coché n'est pas recompté.
    var effectiveSelection: [DiskNode] {
        selection.values.filter { node in
            var ancestor = node.parent
            while let current = ancestor {
                if selection[current.url] != nil { return false }
                ancestor = current.parent
            }
            return true
        }
    }

    var selectedSize: Int64 {
        effectiveSelection.reduce(0) { $0 + $1.size }
    }

    // MARK: - Suppression

    func delete(mode: DeletionMode) {
        let nodes = effectiveSelection
        guard !nodes.isEmpty else { return }
        let items = nodes.map { node in
            CleanupItem(url: node.url, name: node.name, detail: nil, group: "", size: node.size,
                        modified: nil, risk: .review, preselected: false)
        }
        phase = .deleting

        task = Task { [weak self] in
            let report = await Deleter.delete(items, mode: mode)
            guard let self else { return }
            let failed = Set(report.failures.map(\.url))
            for node in nodes where !failed.contains(node.url) { self.remove(node) }
            self.selection = [:]
            self.report = report
            self.phase = .ready
            NotificationCenter.default.post(name: .balaiDidDelete, object: nil)
        }
    }

    /// Retire un élément de l'arbre et déduit sa taille de tous ses dossiers parents.
    private func remove(_ node: DiskNode) {
        guard let parent = node.parent else { return }
        parent.children.removeAll { $0 === node }
        var ancestor: DiskNode? = parent
        while let current = ancestor {
            current.size -= node.size
            ancestor = current.parent
        }
        // Si le dossier affiché a été supprimé, on remonte au premier parent encore présent.
        if let index = path.firstIndex(where: { $0 === node }) {
            path.removeSubrange(index...)
        }
        objectWillChange.send()
    }
}
