import SwiftUI
import AppKit

struct UninstallerView: View {
    @ObservedObject var vm: UninstallerViewModel
    @State private var showConfirmation = false

    private let category = CleanupCategory.uninstaller
    private var theme: Theme { category.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text(category.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.leading, 4)

            HStack(spacing: 14) {
                appList
                    .frame(width: 290)
                    .frame(maxHeight: .infinity)
                    .panel(cornerRadius: 18)
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .panel(cornerRadius: 18)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 20)
        .animation(.balai, value: vm.selectedAppID)
        .onAppear { if vm.apps.isEmpty { vm.loadApps() } }
        .sheet(isPresented: $showConfirmation) {
            DeleteConfirmationView(
                theme: theme,
                title: L("Désinstaller \(vm.selectedApp?.name ?? "l'app") ?", "Uninstall \(vm.selectedApp?.name ?? "the app")?"),
                count: vm.selectedLeftovers.count,
                size: vm.selectedSize,
                warning: vm.selectedApp.map(AppUninstaller.isRunning) == true
                    ? L("L'app est encore ouverte : quittez-la d'abord pour éviter les erreurs.",
                        "The app is still running: quit it first to avoid errors.")
                    : nil,
                onConfirm: { vm.uninstall(mode: $0) }
            )
        }
    }

    // MARK: - Liste des apps

    private var appList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                searchField
                Button { vm.loadApps() } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L("Actualiser la liste des apps", "Refresh the app list"))
                .disabled(vm.isLoadingApps)
            }
            .padding(12)

            if vm.isLoadingApps {
                Spacer()
                ProgressView().controlSize(.small)
                Text(L("Recherche des applications…", "Looking for apps…"))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 8)
                Spacer()
            } else if vm.filteredApps.isEmpty {
                Spacer()
                Text(L("Aucun résultat", "No results"))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(vm.filteredApps) { app in
                            AppRow(app: app, isSelected: vm.selectedAppID == app.id) { vm.selectedAppID = app.id }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.55))
            TextField("", text: $vm.searchText, prompt: Text(L("Rechercher une app", "Search apps")))
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
            if !vm.searchText.isEmpty {
                Button { vm.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.1), in: Capsule())
    }

    // MARK: - Détail

    @ViewBuilder
    private var detail: some View {
        if let app = vm.selectedApp {
            if vm.isLoadingLeftovers {
                busy(L("Recherche des fichiers résiduels…", "Looking for leftover files…"))
            } else if vm.isDeleting {
                busy(L("Désinstallation en cours…", "Uninstalling…"))
            } else {
                VStack(spacing: 0) {
                    appHeader(app).padding(16)
                    if let report = vm.report {
                        ReportRow(report: report) { vm.report = nil }.padding(.horizontal, 16).padding(.bottom, 8)
                    }
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                    ItemGroupsList(
                        groups: vm.leftoverGroups,
                        items: vm.leftovers(in:),
                        isSelected: { vm.leftoverSelection.contains($0) },
                        binding: vm.binding(for:),
                        setGroup: { group, isOn in
                            let ids = vm.leftovers(in: group).map(\.id)
                            if isOn { vm.leftoverSelection.formUnion(ids) } else { vm.leftoverSelection.subtract(ids) }
                        },
                        accent: theme.accent
                    )
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                    SelectionFooter(
                        count: vm.leftoverSelection.count,
                        size: vm.selectedSize,
                        actionTitle: L("Désinstaller", "Uninstall"),
                        accent: theme.accent,
                        allSelected: vm.leftoverSelection.count == vm.leftovers.count,
                        onToggleAll: { vm.leftoverSelection = $0 ? Set(vm.leftovers.map(\.id)) : [] },
                        onAction: { showConfirmation = true }
                    )
                    .padding(14)
                }
            }
        } else {
            VStack(spacing: 14) {
                HeroArt(symbol: category.artSymbol, colors: theme.art, size: 110)
                Text(L("Choisissez une application", "Choose an app"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 14)
                Text(L("Balai retrouvera ses préférences, caches et données éparpillées dans ~/Library.",
                       "Balai will find its preferences, caches and data scattered across ~/Library."))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
                if let report = vm.report {
                    ReportRow(report: report) { vm.report = nil }.frame(maxWidth: 440).padding(.top, 8)
                }
            }
            .padding(24)
        }
    }

    private func busy(_ message: String) -> some View {
        VStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(message).font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
        }
    }

    private func appHeader(_ app: InstalledApp) -> some View {
        HStack(spacing: 14) {
            FileIcon(url: app.url, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Text([app.version.map { "Version \($0)" }, app.bundleID].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                if AppUninstaller.isRunning(app) {
                    HStack(spacing: 8) {
                        Circle().fill(Color.orange).frame(width: 7, height: 7)
                        Text(L("Ouverte", "Running"))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.75))
                        GhostButton(title: L("Quitter l'app", "Quit App")) { AppUninstaller.quit(app) }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 16)
            VStack(alignment: .trailing, spacing: 1) {
                Text(Format.bytes(vm.leftovers.reduce(0) { $0 + $1.size }))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(L("\(vm.leftovers.count) élément(s)", "\(vm.leftovers.count) item(s)"))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }
}

private struct AppRow: View {
    let app: InstalledApp
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                FileIcon(url: app.url, size: 30)
                Text(app.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                if let size = app.size {
                    Text(Format.bytes(size))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(isSelected ? 0.18 : (isHovered ? 0.07 : 0)),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
