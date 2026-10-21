import SwiftUI
import AppKit

/// Explorateur d'espace : tout le disque en bulles, dossier par dossier.
struct SpaceLensView: View {
    @ObservedObject var vm: SpaceLensViewModel
    @State private var showConfirmation = false
    @State private var disk = DiskInfo.current()

    private let category = CleanupCategory.spaceLens
    private var theme: Theme { category.theme }

    var body: some View {
        content
            .animation(.balai, value: vm.phase.stage)
            .onReceive(NotificationCenter.default.publisher(for: .balaiDidDelete)) { _ in disk = .current() }
            .sheet(isPresented: $showConfirmation) {
                DeleteConfirmationView(
                    theme: theme,
                    title: L("Supprimer la sélection ?", "Remove the selection?"),
                    count: vm.effectiveSelection.count,
                    size: vm.selectedSize,
                    warning: L("Vérifiez bien : ces éléments ne sont pas des caches et ne seront pas recréés.",
                               "Double-check: these items are not caches and will not be recreated."),
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
                if !Permissions.hasFullDiskAccess {
                    Button { Permissions.openFullDiskAccessSettings() } label: {
                        Label(L("Accordez l'accès complet au disque pour tout voir", "Grant Full Disk Access to see everything"),
                              systemImage: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
            } action: {
                ScanButton(title: L("Analyser", "Scan"), accent: theme.accent) { vm.scan() }
                    .keyboardShortcut(.defaultAction)
            }

        case .scanning(let path, let files):
            HeroPage(title: L("Analyse du disque…", "Scanning your disk…"), subtitle: path) {
                HeroArt(symbol: category.artSymbol, colors: theme.art, isAnimating: true)
            } extra: {
                Text(L("\(files.formatted()) fichiers analysés", "\(files.formatted()) files scanned"))
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))
            } action: {
                ScanButton(title: L("Arrêter", "Stop"), accent: theme.accent, isBusy: true) { vm.cancel() }
            }

        case .deleting:
            HeroPage(title: L("Suppression en cours…", "Removing…"), subtitle: L("Merci de patienter.", "Please wait.")) {
                HeroArt(symbol: "trash.fill", colors: theme.art, isAnimating: true)
            } extra: {
                EmptyView()
            } action: {
                ScanButton(title: "", accent: theme.accent, isBusy: true, isEnabled: false) {}
            }

        case .ready:
            if let current = vm.current {
                explorer(current)
            }
        }
    }

    // MARK: - Explorateur

    private func explorer(_ current: DiskNode) -> some View {
        HStack(spacing: 16) {
            VStack(spacing: 12) {
                diskCard
                folderPanel(current)
            }
            .frame(width: 340)

            VStack(spacing: 12) {
                header
                if let report = vm.report {
                    ReportRow(report: report) { vm.report = nil }
                }
                BubbleChart(node: current, accent: theme.accent,
                            isSelected: { vm.selection[$0.url] != nil }) { node in
                    if node.canOpen {
                        vm.open(node)
                    } else if vm.isDeletable(node) {
                        vm.binding(for: node).wrappedValue.toggle()
                    }
                }
                .id(current.url)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                footer
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 20)
        .animation(.balai, value: vm.path.count)
    }

    private var diskCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(vm.root?.name ?? "Macintosh HD").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(L("\(Format.bytes(disk.used)) utilisés sur \(Format.bytes(disk.total))",
                       "\(Format.bytes(disk.used)) of \(Format.bytes(disk.total)) used"))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .foregroundStyle(.white)
            GeometryReader { geo in
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(LinearGradient(colors: [.white.opacity(0.9), theme.accent],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: disk.total > 0 ? geo.size.width * CGFloat(disk.used) / CGFloat(disk.total) : 0)
                    }
            }
            .frame(height: 6)
            if let duration = vm.scanDuration {
                Text(L("Analysé en \(Int(duration)) s", "Scanned in \(Int(duration)) s"))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(14)
        .panel(cornerRadius: 16)
    }

    private func folderPanel(_ current: DiskNode) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                FileIcon(url: current.url, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(current.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(L("\(Format.bytes(current.size))  |  \(current.itemCount) éléments",
                           "\(Format.bytes(current.size))  |  \(current.itemCount) items"))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                        .monospacedDigit()
                }
            }
            .padding(14)

            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(current.children) { node in
                        NodeRow(node: node,
                                isDeletable: vm.isDeletable(node),
                                isOn: vm.binding(for: node)) { vm.open(node) }
                    }
                    if current.otherSize > 0 {
                        HStack(spacing: 10) {
                            Image(systemName: "ellipsis.circle")
                                .frame(width: 16)
                                .foregroundStyle(.white.opacity(0.4))
                            Text(L("\(current.otherCount) éléments plus petits", "\(current.otherCount) smaller items"))
                                .foregroundStyle(.white.opacity(0.6))
                            Spacer()
                            Text(Format.bytes(current.otherSize))
                                .foregroundStyle(.white.opacity(0.5))
                                .monospacedDigit()
                        }
                        .font(.system(size: 12))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                    if current.isRestricted {
                        Label(L("Accès refusé : accordez l'accès complet au disque.", "Access denied: grant Full Disk Access."),
                              systemImage: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(12)
                    }
                }
                .padding(8)
            }
        }
        .frame(maxHeight: .infinity)
        .panel(cornerRadius: 18)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { vm.goBack() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .disabled(vm.path.count <= 1)
            .opacity(vm.path.count <= 1 ? 0.4 : 1)

            breadcrumb
            Spacer(minLength: 8)
            GhostButton(title: L("Analyser à nouveau", "Scan Again"), systemImage: "arrow.clockwise") { vm.scan() }
        }
    }

    /// Fil d'Ariane : la racine, puis les deux derniers niveaux ; ceux du milieu deviennent « … ».
    private var breadcrumb: some View {
        let indices = Array(vm.path.indices)
        let tail = Array(indices.dropFirst().suffix(2))
        let isShortened = indices.count > tail.count + 1
        return HStack(spacing: 4) {
            crumb(0, showsName: indices.count == 1)
            if isShortened {
                separator
                Button { vm.go(to: indices.count - 4) } label: { Text("…") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.6))
                    .help(L("Remonter", "Go up"))
            }
            ForEach(tail, id: \.self) { index in
                separator
                crumb(index, showsName: true)
                    .layoutPriority(index == indices.last ? 2 : 1)
            }
        }
        .font(.system(size: 12, weight: .medium))
    }

    private var separator: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white.opacity(0.4))
    }

    private func crumb(_ index: Int, showsName: Bool) -> some View {
        Button { vm.go(to: index) } label: {
            HStack(spacing: 5) {
                FileIcon(url: vm.path[index].url, size: 16)
                if showsName {
                    Text(vm.path[index].name).lineLimit(1).truncationMode(.middle)
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(index == vm.path.count - 1 ? 1 : 0.7))
        .help(vm.path[index].url.path)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Spacer()
            Text(L("\(vm.effectiveSelection.count) élément(s) sélectionné(s)", "\(vm.effectiveSelection.count) item(s) selected"))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .fixedSize()
            Rectangle().fill(Color.white.opacity(0.25)).frame(width: 1, height: 16)
            Text(Format.bytes(vm.selectedSize))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .monospacedDigit()
            PillButton(title: L("Revoir et supprimer", "Review and Remove"), accent: theme.accent,
                       isEnabled: !vm.selection.isEmpty) { showConfirmation = true }
        }
        .font(.system(size: 13))
    }
}

/// Ligne de la liste : case à cocher (ou cadenas si l'élément est protégé), taille et accès au dossier.
private struct NodeRow: View {
    let node: DiskNode
    let isDeletable: Bool
    @Binding var isOn: Bool
    let onOpen: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            if isDeletable {
                Toggle("", isOn: $isOn)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(width: 16)
                    .help(L("Protégé : Balai ne supprime rien ici.", "Protected: Balai never removes anything here."))
            }
            FileIcon(url: node.url, size: 24)
            Text(node.name)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)
            if node.isRestricted {
                Image(systemName: "eye.slash")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .help(L("Contenu illisible sans l'accès complet au disque", "Unreadable without Full Disk Access"))
            }
            Spacer(minLength: 8)
            Text(Format.bytes(node.size))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(node.canOpen ? 0.5 : 0))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(isHovered ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            if node.canOpen { onOpen() } else if isDeletable { isOn.toggle() }
        }
        .onHover { isHovered = $0 }
        .help(node.url.path)
        .contextMenu {
            Button(L("Afficher dans le Finder", "Show in Finder")) {
                NSWorkspace.shared.activateFileViewerSelecting([node.url])
            }
            Button(L("Copier le chemin", "Copy Path")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(node.url.path, forType: .string)
            }
        }
    }
}
