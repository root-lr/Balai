import SwiftUI

/// État d'un module d'analyse (caches, dev, gros fichiers).
@MainActor
final class ScanViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case scanning(String)
        case ready
        case deleting

        /// Étape, sans le message de progression : sert de clé d'animation.
        var stage: Int {
            switch self {
            case .idle: return 0
            case .scanning: return 1
            case .ready: return 2
            case .deleting: return 3
            }
        }
    }

    @Published private(set) var items: [CleanupItem] = []
    @Published var selection: Set<URL> = []
    @Published private(set) var phase: Phase = .idle
    @Published var report: DeletionReport?
    /// Message du module quand il ne peut rien analyser (outil absent, moteur arrêté…).
    @Published private(set) var notice: String?

    private let makeScanner: () -> any Scanner
    private var task: Task<Void, Never>?

    init(makeScanner: @escaping () -> any Scanner) {
        self.makeScanner = makeScanner
    }

    // MARK: - Données dérivées

    /// Noms des sections, dans l'ordre d'apparition.
    var groups: [String] {
        var seen = Set<String>()
        return items.map(\.group).filter { seen.insert($0).inserted }
    }

    func items(in group: String) -> [CleanupItem] {
        items.filter { $0.group == group }
    }

    var selectedItems: [CleanupItem] {
        items.filter { selection.contains($0.id) }
    }

    var selectedSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    func binding(for id: URL) -> Binding<Bool> {
        Binding(
            get: { [weak self] in self?.selection.contains(id) ?? false },
            set: { [weak self] isOn in
                if isOn { self?.selection.insert(id) } else { self?.selection.remove(id) }
            }
        )
    }

    func setSelection(_ isOn: Bool, for group: String? = nil) {
        let ids = (group.map { items(in: $0) } ?? items).map(\.id)
        if isOn { selection.formUnion(ids) } else { selection.subtract(ids) }
    }

    // MARK: - Actions

    func scan() {
        task?.cancel()
        report = nil
        phase = .scanning(L("Préparation…", "Preparing…"))
        let scanner = makeScanner()
        let progress: @Sendable (String) -> Void = { [weak self] message in
            guard let viewModel = self else { return }
            Task { @MainActor in
                guard case .scanning = viewModel.phase else { return }
                viewModel.phase = .scanning(message)
            }
        }

        task = Task { [weak self] in
            if let reason = await scanner.unavailableReason() {
                guard let self, !Task.isCancelled else { return }
                self.notice = reason
                self.items = []
                self.selection = []
                self.phase = .ready
                return
            }
            let found = await scanner.scan(progress: progress)
            guard let self, !Task.isCancelled else { return }
            self.notice = nil
            self.items = found
            self.selection = Set(found.filter(\.preselected).map(\.id))
            self.phase = .ready
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = items.isEmpty ? .idle : .ready
    }

    func delete(mode: DeletionMode) {
        let toDelete = selectedItems
        guard !toDelete.isEmpty else { return }
        phase = .deleting

        task = Task { [weak self] in
            let report = await Deleter.delete(toDelete, mode: mode)
            guard let self else { return }
            let failed = Set(report.failures.map(\.url))
            let removed = Set(toDelete.map(\.id)).subtracting(failed)
            self.items.removeAll { removed.contains($0.id) }
            self.selection.subtract(removed)
            self.report = report
            self.phase = .ready
            NotificationCenter.default.post(name: .balaiDidDelete, object: nil)
        }
    }
}
