import SwiftUI

/// Analyse intelligente : lance les trois analyses d'un coup et nettoie la sélection en une fois.
struct OverviewView: View {
    @ObservedObject var cachesVM: ScanViewModel
    @ObservedObject var devVM: ScanViewModel
    @ObservedObject var largeFilesVM: ScanViewModel
    let onOpen: (CleanupCategory) -> Void

    @State private var showConfirmation = false

    private let theme = Theme.overview

    private var modules: [(category: CleanupCategory, vm: ScanViewModel)] {
        [(.caches, cachesVM), (.devFiles, devVM), (.largeFiles, largeFilesVM)]
    }

    private var vms: [ScanViewModel] { modules.map(\.vm) }

    private var scanningMessage: String? {
        for vm in vms { if case .scanning(let message) = vm.phase { return message } }
        return nil
    }

    private var isDeleting: Bool { vms.contains { $0.phase == .deleting } }
    private var reports: [DeletionReport] { vms.compactMap(\.report) }
    private var hasResults: Bool { vms.contains { $0.phase == .ready } }
    private var selectedCount: Int { vms.reduce(0) { $0 + $1.selection.count } }
    private var selectedSize: Int64 { vms.reduce(0) { $0 + $1.selectedSize } }
    private var foundSize: Int64 { vms.reduce(0) { $0 + ($1.phase == .ready ? $1.totalSize : 0) } }

    var body: some View {
        content
            .animation(.balai, value: hasResults)
            .sheet(isPresented: $showConfirmation) {
                DeleteConfirmationView(
                    theme: theme,
                    title: L("Nettoyer la sélection ?", "Clean up the selection?"),
                    count: selectedCount,
                    size: selectedSize,
                    warning: vms.contains { $0.selectedItems.contains { $0.risk == .review } }
                        ? L("Certains éléments sélectionnés sont marqués « À vérifier ».",
                            "Some selected items are marked “Review”.")
                        : nil,
                    onConfirm: { mode in vms.forEach { $0.delete(mode: mode) } }
                )
            }
    }

    @ViewBuilder
    private var content: some View {
        if let message = scanningMessage {
            HeroPage(title: L("Analyse en cours…", "Scanning…"), subtitle: message) {
                BrandIcon(size: 230)
            } extra: {
                EmptyView()
            } action: {
                ScanButton(title: L("Arrêter", "Stop"), accent: theme.accent, isBusy: true) {
                    vms.forEach { $0.cancel() }
                }
            }
        } else if isDeleting {
            HeroPage(title: L("Nettoyage en cours…", "Cleaning up…"), subtitle: L("Merci de patienter.", "Please wait.")) {
                BrandIcon(size: 230)
            } extra: {
                EmptyView()
            } action: {
                ScanButton(title: "", accent: theme.accent, isBusy: true, isEnabled: false) {}
            }
        } else if !reports.isEmpty {
            completion
        } else if hasResults {
            results
        } else {
            HeroPage(title: L("Bienvenue dans Balai", "Welcome to Balai"),
                     subtitle: L("Commencez par une analyse complète de votre Mac. Rien n'est supprimé sans votre accord.",
                                 "Start with a thorough scan of your Mac. Nothing is removed without your approval.")) {
                BrandIcon(size: 230)
            } extra: {
                EmptyView()
            } action: {
                ScanButton(title: L("Analyser", "Scan"), accent: theme.accent) { vms.forEach { $0.scan() } }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var results: some View {
        HeroPage(title: L("Analyse terminée", "Scan complete"),
                 subtitle: L("\(Format.bytes(foundSize)) trouvés · \(Format.bytes(selectedSize)) sélectionnés pour le nettoyage",
                             "\(Format.bytes(foundSize)) found · \(Format.bytes(selectedSize)) selected for cleanup")) {
            HStack(spacing: 14) {
                ForEach(modules, id: \.category) { module in
                    ResultCard(category: module.category, vm: module.vm) { onOpen(module.category) }
                }
            }
            .frame(maxWidth: 760)
        } extra: {
            GhostButton(title: L("Analyser à nouveau", "Scan Again"), systemImage: "arrow.clockwise") {
                vms.forEach { $0.scan() }
            }
        } action: {
            ScanButton(title: L("Nettoyer", "Clean"), accent: theme.accent, isEnabled: selectedCount > 0) {
                showConfirmation = true
            }
        }
    }

    private var completion: some View {
        let freed = reports.reduce(0) { $0 + $1.bytes }
        let toTrash = reports.contains { $0.mode == .trash }
        let failures = reports.reduce(0) { $0 + $1.failures.count }
        var subtitle = toTrash
            ? L("\(Format.bytes(freed)) mis à la Corbeille. Videz-la pour libérer l'espace.",
                "\(Format.bytes(freed)) moved to the Trash. Empty it to free the space.")
            : L("\(Format.bytes(freed)) libérés.", "\(Format.bytes(freed)) freed.")
        if failures > 0 {
            subtitle += " " + L("\(failures) élément(s) n'ont pas pu être supprimés.",
                                "\(failures) item(s) could not be removed.")
        }
        return HeroPage(title: L("C'est propre !", "All clean!"), subtitle: subtitle) {
            HeroArt(symbol: "checkmark", colors: Theme.success)
        } extra: {
            EmptyView()
        } action: {
            ScanButton(title: L("Terminé", "Done"), accent: Theme.success[1]) {
                vms.forEach { $0.report = nil }
            }
        }
    }
}

/// Résultat d'un module sur l'écran d'analyse intelligente.
private struct ResultCard: View {
    let category: CleanupCategory
    @ObservedObject var vm: ScanViewModel
    let onOpen: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 10) {
                HeroArt(symbol: category.artSymbol, colors: category.theme.art, size: 54)
                    .padding(.top, 4)
                Text(category.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                status
                Text(L("Revoir les détails", "Review Details"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(isHovered ? 0.95 : 0.6))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .panel(cornerRadius: 18)
            .scaleEffect(isHovered ? 1.03 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(.balai) { isHovered = hovering } }
    }

    @ViewBuilder
    private var status: some View {
        switch vm.phase {
        case .ready where vm.items.isEmpty:
            Text(L("Propre", "Clean")).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.success[0])
        case .ready:
            VStack(spacing: 2) {
                Text(Format.bytes(vm.totalSize))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(L("\(Format.bytes(vm.selectedSize)) sélectionnés", "\(Format.bytes(vm.selectedSize)) selected"))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()
            }
        default:
            Text(L("Non analysé", "Not scanned")).font(.system(size: 14)).foregroundStyle(.white.opacity(0.5))
        }
    }
}
