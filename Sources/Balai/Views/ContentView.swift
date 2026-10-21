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
        if let output = env["BALAI_DEMO"] {
            Task { await runDemo(output: URL(fileURLWithPath: output)) }
        }
    }

    /// Scénario du GIF du README (BALAI_DEMO=docs/images/demo.gif BALAI_DETAILS=1).
    /// L'enregistrement est mis en pause pendant les analyses longues, pour garder un GIF court.
    private func runDemo(output: URL) async {
        let recorder = DemoRecorder()
        let scanVMs = [cachesVM, devVM, largeFilesVM]
        spaceLensVM.scan()
        uninstallerVM.loadApps()
        await pause(2)

        // Analyse intelligente
        recorder.isRecording = true
        await pause(2)
        scanVMs.forEach { $0.scan() }
        await pause(2.5)
        recorder.isRecording = false
        await waitUntil { scanVMs.allSatisfy { $0.phase == .ready } }
        recorder.isRecording = true
        await pause(2.5)

        // Détails d'un module
        destination = .module(.caches)
        await pause(2.5)

        // Explorateur d'espace : tout le disque, puis un dossier
        recorder.isRecording = false
        await waitUntil { spaceLensVM.phase == .ready }
        destination = .module(.spaceLens)
        recorder.isRecording = true
        await pause(2.5)
        if let applications = spaceLensVM.current?.children.first(where: { $0.name == "Applications" }) {
            spaceLensVM.open(applications)
        }
        await pause(2.5)

        // Désinstalleur
        recorder.isRecording = false
        let appName = ProcessInfo.processInfo.environment["BALAI_APP"]
        uninstallerVM.selectedAppID = uninstallerVM.apps.first { $0.name == appName }?.id ?? uninstallerVM.apps.first?.id
        destination = .module(.uninstaller)
        await waitUntil { !uninstallerVM.isLoadingLeftovers }
        await pause(0.5)
        recorder.isRecording = true
        await pause(2.5)

        // Retour au début, pour une boucle propre
        destination = .overview
        await pause(1.5)
        recorder.isRecording = false
        recorder.writeGIF(to: output)
        exit(0)
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func waitUntil(_ condition: () -> Bool) async {
        while !condition() { await pause(0.2) }
    }
    #endif
}
