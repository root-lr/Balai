import SwiftUI

/// Écran commun aux modules Caches, Fichiers développeur et Gros fichiers :
/// accueil → analyse → résumé → détails → nettoyage.
struct CleanupModuleView: View {
    let category: CleanupCategory
    @ObservedObject var vm: ScanViewModel

    @State private var showConfirmation = false
    @State private var showDetails = Self.debugShowsDetails

    private var theme: Theme { category.theme }

    var body: some View {
        content
            .animation(.balai, value: vm.phase.stage)
            .animation(.balai, value: showDetails)
            .sheet(isPresented: $showConfirmation) {
                DeleteConfirmationView(
                    theme: theme,
                    title: L("Nettoyer \(category.title.lowercased()) ?", "Clean up \(category.title.lowercased())?"),
                    count: vm.selection.count,
                    size: vm.selectedSize,
                    warning: DeleteConfirmationView.warning(for: vm.selectedItems),
                    onConfirm: { vm.delete(mode: $0) }
                )
            }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.phase {
        case .idle:
            HeroPage(title: category.title, subtitle: category.subtitle) {
                HeroArt(symbol: category.artSymbol, colors: theme.art)
            } extra: {
                Label(L("Rien n'est supprimé sans votre confirmation.", "Nothing is removed without your confirmation."),
                      systemImage: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
            } action: {
                ScanButton(title: L("Analyser", "Scan"), accent: theme.accent) { vm.scan() }
                    .keyboardShortcut(.defaultAction)
            }

        case .scanning(let message):
            HeroPage(title: L("Analyse en cours…", "Scanning…"), subtitle: message) {
                HeroArt(symbol: category.artSymbol, colors: theme.art, isAnimating: true)
            } extra: {
                EmptyView()
            } action: {
                ScanButton(title: L("Arrêter", "Stop"), accent: theme.accent, isBusy: true) { vm.cancel() }
            }

        case .deleting:
            HeroPage(title: L("Nettoyage en cours…", "Cleaning up…"), subtitle: L("Merci de patienter.", "Please wait.")) {
                HeroArt(symbol: "trash.fill", colors: theme.art, isAnimating: true)
            } extra: {
                EmptyView()
            } action: {
                ScanButton(title: "", accent: theme.accent, isBusy: true, isEnabled: false) {}
            }

        case .ready:
            if let report = vm.report {
                completion(report)
            } else if let notice = vm.notice {
                HeroPage(title: L("Rien à analyser pour l'instant", "Nothing to scan right now"), subtitle: notice) {
                    HeroArt(symbol: "exclamationmark", colors: [Color(hex: 0xFFD180), Color(hex: 0xF57C00)])
                } extra: {
                    EmptyView()
                } action: {
                    ScanButton(title: L("Réessayer", "Retry"), accent: theme.accent) { vm.scan() }
                }
            } else if vm.items.isEmpty {
                HeroPage(title: L("Tout est propre", "All clean"),
                         subtitle: L("Rien à nettoyer ici pour le moment.", "Nothing to clean up here right now.")) {
                    HeroArt(symbol: "checkmark", colors: Theme.success)
                } extra: {
                    EmptyView()
                } action: {
                    ScanButton(title: L("Analyser", "Scan"), accent: theme.accent) { vm.scan() }
                }
            } else if showDetails {
                details
            } else {
                summary
            }
        }
    }

    // MARK: - Résumé

    private var summary: some View {
        HeroPage(title: L("Analyse terminée", "Scan complete"),
                 subtitle: category.measuresSpace
                    ? L("\(vm.items.count) élément(s) trouvé(s) · \(Format.bytes(vm.totalSize))",
                        "\(vm.items.count) item(s) found · \(Format.bytes(vm.totalSize))")
                    : L("\(vm.items.count) élément(s) trouvé(s)", "\(vm.items.count) item(s) found")) {
            HeroArt(symbol: category.artSymbol, colors: theme.art, size: 150)
        } extra: {
            VStack(spacing: 4) {
                // Pour le démarrage, on compte des agents : leur poids n'a pas de sens.
                Text(category.measuresSpace ? Format.bytes(vm.selectedSize) : "\(vm.selection.count)")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(L("sélectionnés pour le nettoyage", "selected for cleanup"))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))
                GhostButton(title: L("Revoir les détails", "Review Details"), systemImage: "list.bullet") {
                    showDetails = true
                }
                .padding(.top, 10)
            }
        } action: {
            ScanButton(title: L("Nettoyer", "Clean"), accent: theme.accent, isEnabled: !vm.selection.isEmpty) {
                showConfirmation = true
            }
        }
    }

    // MARK: - Détails

    private var details: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                GhostButton(title: L("Retour", "Back"), systemImage: "chevron.left") { showDetails = false }
                VStack(alignment: .leading, spacing: 1) {
                    Text(category.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text(L("\(vm.items.count) élément(s) · \(Format.bytes(vm.totalSize))",
                           "\(vm.items.count) item(s) · \(Format.bytes(vm.totalSize))"))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                GhostButton(title: L("Analyser à nouveau", "Scan Again"), systemImage: "arrow.clockwise") {
                    showDetails = false
                    vm.scan()
                }
            }

            ItemGroupsList(
                groups: vm.groups,
                items: vm.items(in:),
                isSelected: { vm.selection.contains($0) },
                binding: vm.binding(for:),
                setGroup: { group, isOn in vm.setSelection(isOn, for: group) },
                accent: theme.accent
            )
            .panel(cornerRadius: 18)

            SelectionFooter(
                count: vm.selection.count,
                size: vm.selectedSize,
                actionTitle: L("Nettoyer", "Clean Up"),
                accent: theme.accent,
                allSelected: vm.selection.count == vm.items.count,
                onToggleAll: { vm.setSelection($0) },
                onAction: { showConfirmation = true }
            )
            .padding(.horizontal, 6)
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 18)
    }

    // MARK: - Bilan

    private func completion(_ report: DeletionReport) -> some View {
        HeroPage(title: report.failures.isEmpty ? L("C'est propre !", "All clean!") : L("Nettoyage terminé", "Cleanup finished"),
                 subtitle: [report.summary, report.failureSummary].compactMap { $0 }.joined(separator: " ")) {
            HeroArt(symbol: report.failures.isEmpty ? "checkmark" : "exclamationmark",
                    colors: report.failures.isEmpty ? Theme.success : [Color(hex: 0xFFD180), Color(hex: 0xF57C00)])
        } extra: {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(report.failures.prefix(3)) { failure in
                    Text("\(failure.name ?? Format.abbreviate(failure.url)) — \(failure.reason)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: 520)
        } action: {
            ScanButton(title: L("Terminé", "Done"), accent: Theme.success[1]) {
                vm.report = nil
                showDetails = false
            }
        }
    }

    private static var debugShowsDetails: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["BALAI_DETAILS"] == "1"
        #else
        false
        #endif
    }
}
