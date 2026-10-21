import SwiftUI

@MainActor
final class UninstallerViewModel: ObservableObject {
    @Published private(set) var apps: [InstalledApp] = []
    @Published private(set) var isLoadingApps = false
    @Published var searchText = ""

    @Published var selectedAppID: URL? {
        didSet { if oldValue != selectedAppID { loadLeftovers() } }
    }
    @Published private(set) var leftovers: [CleanupItem] = []
    @Published var leftoverSelection: Set<URL> = []
    @Published private(set) var isLoadingLeftovers = false

    @Published private(set) var isDeleting = false
    @Published var report: DeletionReport?

    private var appsTask: Task<Void, Never>?
    private var leftoversTask: Task<Void, Never>?

    var filteredApps: [InstalledApp] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || ($0.bundleID?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var selectedApp: InstalledApp? {
        apps.first { $0.id == selectedAppID }
    }

    var leftoverGroups: [String] {
        var seen = Set<String>()
        return leftovers.map(\.group).filter { seen.insert($0).inserted }
    }

    func leftovers(in group: String) -> [CleanupItem] {
        leftovers.filter { $0.group == group }
    }

    var selectedLeftovers: [CleanupItem] {
        leftovers.filter { leftoverSelection.contains($0.id) }
    }

    var selectedSize: Int64 {
        selectedLeftovers.reduce(0) { $0 + $1.size }
    }

    func binding(for id: URL) -> Binding<Bool> {
        Binding(
            get: { [weak self] in self?.leftoverSelection.contains(id) ?? false },
            set: { [weak self] isOn in
                if isOn { self?.leftoverSelection.insert(id) } else { self?.leftoverSelection.remove(id) }
            }
        )
    }

    // MARK: - Chargement

    func loadApps() {
        appsTask?.cancel()
        isLoadingApps = true

        appsTask = Task { [weak self] in
            let list = await AppUninstaller.installedApps()
            guard let self, !Task.isCancelled else { return }
            self.apps = list
            self.isLoadingApps = false
            #if DEBUG
            if let name = ProcessInfo.processInfo.environment["BALAI_APP"] {
                self.selectedAppID = list.first { $0.name == name }?.id
            }
            #endif

            // Les tailles arrivent ensuite, par petits lots, pour que la liste s'affiche tout de suite.
            var pending: [URL: Int64] = [:]
            for app in list {
                if Task.isCancelled { return }
                pending[app.id] = await AppUninstaller.size(of: app)
                if pending.count >= 10 || app.id == list.last?.id {
                    for index in self.apps.indices {
                        if let size = pending[self.apps[index].id] { self.apps[index].size = size }
                    }
                    pending.removeAll()
                }
            }
        }
    }

    private func loadLeftovers() {
        leftoversTask?.cancel()
        leftovers = []
        leftoverSelection = []
        isLoadingLeftovers = false
        guard let app = selectedApp else { return }
        isLoadingLeftovers = true

        leftoversTask = Task { [weak self] in
            let found = await AppUninstaller.leftovers(for: app)
            guard let self, !Task.isCancelled, self.selectedAppID == app.id else { return }
            self.leftovers = found
            self.leftoverSelection = Set(found.filter(\.preselected).map(\.id))
            self.isLoadingLeftovers = false
        }
    }

    // MARK: - Désinstallation

    func uninstall(mode: DeletionMode) {
        let toDelete = selectedLeftovers
        guard let app = selectedApp, !toDelete.isEmpty else { return }
        isDeleting = true

        Task { [weak self] in
            let report = await Deleter.delete(toDelete, mode: mode)
            guard let self else { return }
            let failed = Set(report.failures.map(\.url))
            let appRemoved = toDelete.contains { $0.id == app.url } && !failed.contains(app.url)

            if appRemoved {
                self.apps.removeAll { $0.id == app.id }
                self.selectedAppID = nil
            } else {
                let removed = Set(toDelete.map(\.id)).subtracting(failed)
                self.leftovers.removeAll { removed.contains($0.id) }
                self.leftoverSelection.subtract(removed)
            }
            self.report = report
            self.isDeleting = false
            NotificationCenter.default.post(name: .balaiDidDelete, object: nil)
        }
    }
}
