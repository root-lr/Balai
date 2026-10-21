import SwiftUI

struct ContentView: View {
    @State private var destination: Destination = .overview
    /// Observé pour redessiner toute l'interface quand la langue change dans les Réglages.
    @AppStorage(Defaults.language) private var language = AppLanguage.system.rawValue

    @StateObject private var cachesVM = ScanViewModel { CacheScanner() }
    @StateObject private var devVM = ScanViewModel { DevScanner(staleDays: Defaults.staleDays) }
    @StateObject private var largeFilesVM = ScanViewModel {
        LargeFileScanner(thresholdBytes: Defaults.largeFileThresholdBytes)
    }
    @StateObject private var uninstallerVM = UninstallerViewModel()
    @StateObject private var spaceLensVM = SpaceLensViewModel()

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(selection: $destination) { badge(for: $0) }
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background {
            ZStack {
                ThemeBackground(theme: destination.theme)
                    .id(destination)
                    .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.45), value: destination)
            .ignoresSafeArea()
        }
        .ignoresSafeArea(.container, edges: .top)
        .environment(\.locale, AppLanguage.resolved.locale)
        .id(language)
        #if DEBUG
        .onAppear(perform: applyDebugLaunchOptions)
        #endif
    }

    @ViewBuilder
    private var detail: some View {
        switch destination {
        case .overview:
            OverviewView(cachesVM: cachesVM, devVM: devVM, largeFilesVM: largeFilesVM) { destination = .module($0) }
        case .module(.uninstaller):
            UninstallerView(vm: uninstallerVM)
        case .module(.spaceLens):
            SpaceLensView(vm: spaceLensVM)
        case .module(let category):
            CleanupModuleView(category: category, vm: scanVM(for: category))
                .id(category)
        }
    }

    private func scanVM(for category: CleanupCategory) -> ScanViewModel {
        switch category {
        case .devFiles: return devVM
        case .largeFiles: return largeFilesVM
        default: return cachesVM
        }
    }

    /// Taille trouvée par la dernière analyse, affichée dans la barre latérale.
    private func foundSize(in vm: ScanViewModel) -> String? {
        guard vm.phase == .ready, !vm.items.isEmpty else { return nil }
        return Format.bytes(vm.totalSize)
    }

    private func badge(for category: CleanupCategory) -> String? {
        switch category {
        case .caches, .devFiles, .largeFiles: return foundSize(in: scanVM(for: category))
        case .spaceLens: return spaceLensVM.root.map { Format.bytes($0.size) }
        case .uninstaller: return nil
        }
    }

    #if DEBUG
    /// BALAI_PAGE=caches|devFiles|largeFiles|uninstaller, BALAI_AUTOSCAN=1 (voir DebugSnapshot).
    private func applyDebugLaunchOptions() {
        let env = ProcessInfo.processInfo.environment
        if let page = env["BALAI_PAGE"], let category = CleanupCategory(rawValue: page) {
            destination = .module(category)
        }
        if env["BALAI_AUTOSCAN"] == "1" {
            if destination == .module(.spaceLens) {
                spaceLensVM.scan()
            } else {
                [cachesVM, devVM, largeFilesVM].forEach { $0.scan() }
            }
        }
    }
    #endif
}
