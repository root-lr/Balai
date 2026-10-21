import SwiftUI

struct ContentView: View {
    @State private var destination: Destination = .overview
    /// Observé pour redessiner toute l'interface quand la langue change dans les Réglages.
    @AppStorage(Defaults.language) private var language = AppLanguage.system.rawValue

    @StateObject private var store = ModuleStore()

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(selection: $destination) { store.badge(for: $0) }
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
            OverviewView(store: store) { destination = .module($0) }
        case .module(.uninstaller):
            UninstallerView(vm: store.uninstaller)
        case .module(.spaceLens):
            SpaceLensView(vm: store.spaceLens)
        case .module(let category):
            if let viewModel = store.scanner(category) {
                CleanupModuleView(category: category, vm: viewModel)
                    .id(category)
            }
        }
    }

    #if DEBUG
    /// BALAI_PAGE=<module> (caches, containers, aiModels…), BALAI_AUTOSCAN=1 (voir DebugSnapshot).
    private func applyDebugLaunchOptions() {
        let env = ProcessInfo.processInfo.environment
        if let page = env["BALAI_PAGE"], let category = CleanupCategory(rawValue: page) {
            destination = .module(category)
        }
        if env["BALAI_AUTOSCAN"] == "1" {
            if case .module(let category) = destination, let viewModel = store.scanner(category) {
                viewModel.scan()
            } else if destination == .module(.spaceLens) {
                store.spaceLens.scan()
            } else {
                ModuleStore.smartScan.compactMap(store.scanner).forEach { $0.scan() }
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
        let scanVMs = ModuleStore.smartScan.compactMap(store.scanner)
        store.spaceLens.scan()
        store.uninstaller.loadApps()
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
        await waitUntil { store.spaceLens.phase == .ready }
        destination = .module(.spaceLens)
        recorder.isRecording = true
        await pause(2.5)
        if let applications = store.spaceLens.current?.children.first(where: { $0.name == "Applications" }) {
            store.spaceLens.open(applications)
        }
        await pause(2.5)

        // Désinstalleur
        recorder.isRecording = false
        let appName = ProcessInfo.processInfo.environment["BALAI_APP"]
        store.uninstaller.selectedAppID = store.uninstaller.apps.first { $0.name == appName }?.id ?? store.uninstaller.apps.first?.id
        destination = .module(.uninstaller)
        await waitUntil { !store.uninstaller.isLoadingLeftovers }
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
