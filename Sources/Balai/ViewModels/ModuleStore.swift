import SwiftUI
import Combine

/// État de tous les modules, partagé par la barre latérale (badges), l'analyse intelligente et les écrans.
@MainActor
final class ModuleStore: ObservableObject {
    /// Modules d'analyse classiques, dans l'ordre de la barre latérale.
    let scanners: [CleanupCategory: ScanViewModel]
    let uninstaller = UninstallerViewModel()
    let spaceLens = SpaceLensViewModel()

    /// Modules lancés par l'analyse intelligente : rapides, et dont la sélection par défaut est sûre.
    static let smartScan: [CleanupCategory] = [.caches, .devFiles, .containers, .largeFiles]

    private var subscriptions: Set<AnyCancellable> = []

    init() {
        scanners = [
            .caches: ScanViewModel { CacheScanner() },
            .devFiles: ScanViewModel { DevScanner(staleDays: Defaults.staleDays) },
            .containers: ScanViewModel { ContainerScanner() },
            .aiModels: ScanViewModel { AIModelScanner() },
            .virtualMachines: ScanViewModel { VirtualMachineScanner() },
            .largeFiles: ScanViewModel { LargeFileScanner(thresholdBytes: Defaults.largeFileThresholdBytes) },
            .duplicates: ScanViewModel { DuplicateScanner() },
            .devices: ScanViewModel { DeviceScanner() },
            .orphans: ScanViewModel { OrphanScanner() },
            .startupItems: ScanViewModel { StartupScanner() },
        ]
        // La vue principale se redessine quand un module change (badges, analyse intelligente).
        for viewModel in scanners.values {
            viewModel.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
        }
        spaceLens.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
    }

    func scanner(_ category: CleanupCategory) -> ScanViewModel? {
        scanners[category]
    }

    /// Texte du badge de la barre latérale : la taille trouvée, ou le nombre d'éléments.
    func badge(for category: CleanupCategory) -> String? {
        if category == .spaceLens { return spaceLens.root.map { Format.bytes($0.size) } }
        guard let viewModel = scanners[category], viewModel.phase == .ready, !viewModel.items.isEmpty else { return nil }
        return category.measuresSpace ? Format.bytes(viewModel.totalSize) : "\(viewModel.items.count)"
    }
}
