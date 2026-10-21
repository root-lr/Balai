import SwiftUI
import AppKit

extension DeletionMode {
    /// Libellé court, pour le sélecteur segmenté.
    var shortLabel: String {
        switch self {
        case .trash: return L("Corbeille", "Trash")
        case .permanent: return L("Définitivement", "Permanently")
        }
    }

    var explanation: String {
        switch self {
        case .trash:
            return L("Récupérable depuis la Corbeille. L'espace n'est libéré qu'une fois la Corbeille vidée.",
                     "Recoverable from the Trash. Space is freed once the Trash is emptied.")
        case .permanent:
            return L("Suppression immédiate et irréversible.", "Removed immediately. This cannot be undone.")
        }
    }
}

extension DeletionReport {
    var summary: String {
        let size = Format.bytes(bytes)
        switch mode {
        case .trash:
            return L("\(deletedCount) élément(s) mis à la Corbeille (\(size)). Videz la Corbeille pour libérer l'espace.",
                     "\(deletedCount) item(s) moved to the Trash (\(size)). Empty the Trash to free the space.")
        case .permanent:
            return L("\(deletedCount) élément(s) supprimé(s) : \(size) libérés.",
                     "\(deletedCount) item(s) removed: \(size) freed.")
        }
    }

    var failureSummary: String? {
        failures.isEmpty ? nil : L("\(failures.count) élément(s) n'ont pas pu être supprimés.",
                                   "\(failures.count) item(s) could not be removed.")
    }
}

/// Espace du disque de démarrage.
struct DiskInfo {
    var total: Int64 = 0
    var available: Int64 = 0

    var used: Int64 { max(total - available, 0) }

    static func current() -> DiskInfo {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? Paths.home.resourceValues(forKeys: keys) else { return DiskInfo() }
        return DiskInfo(total: Int64(values.volumeTotalCapacity ?? 0),
                        available: values.volumeAvailableCapacityForImportantUsage ?? 0)
    }
}

// MARK: - Liste d'éléments

struct FileIcon: View {
    let url: URL
    var size: CGFloat = 24

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}

struct RiskBadge: View {
    var body: some View {
        Text(L("À vérifier", "Review"))
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.22), in: Capsule())
            .foregroundStyle(Color(hex: 0xFFC27A))
    }
}

struct ItemRow: View {
    let item: CleanupItem
    @Binding var isOn: Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $isOn)
                .toggleStyle(.checkbox)
                .labelsHidden()
            FileIcon(url: item.url, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if item.risk == .review { RiskBadge() }
                }
                if let detail = item.detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 16)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.bytes(item.size))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                if let date = item.modified {
                    Text(date, format: .relative(presentation: .named))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.white.opacity(isHovered ? 0.07 : 0), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { isOn.toggle() }
        .onHover { isHovered = $0 }
        .help(item.url.path)
        .contextMenu {
            Button(L("Afficher dans le Finder", "Show in Finder")) {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
            Button(L("Copier le chemin", "Copy Path")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url.path, forType: .string)
            }
        }
    }
}

struct GroupHeader: View {
    let title: String
    let size: Int64
    let allSelected: Bool
    let accent: Color
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            Text(Format.bytes(size))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .monospacedDigit()
            Spacer()
            Button(allSelected ? L("Tout décocher", "Deselect All") : L("Tout cocher", "Select All")) {
                onToggle(!allSelected)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(accent)
        }
    }
}

/// Éléments regroupés par section, cochables un à un ou par groupe.
struct ItemGroupsList: View {
    let groups: [String]
    let items: (String) -> [CleanupItem]
    let isSelected: (URL) -> Bool
    let binding: (URL) -> Binding<Bool>
    let setGroup: (String, Bool) -> Void
    let accent: Color

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groups, id: \.self) { group in
                    let groupItems = items(group)
                    GroupHeader(
                        title: group,
                        size: groupItems.reduce(0) { $0 + $1.size },
                        allSelected: groupItems.allSatisfy { isSelected($0.id) },
                        accent: accent,
                        onToggle: { setGroup(group, $0) }
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                    ForEach(groupItems) { item in
                        ItemRow(item: item, isOn: binding(item.id))
                    }
                }
            }
            .padding(8)
        }
    }
}

/// Bas de liste : sélection, total et action principale.
struct SelectionFooter: View {
    let count: Int
    let size: Int64
    let actionTitle: String
    let accent: Color
    let allSelected: Bool
    let onToggleAll: (Bool) -> Void
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(allSelected ? L("Tout décocher", "Deselect All") : L("Tout cocher", "Select All")) {
                onToggleAll(!allSelected)
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.8))

            Spacer()

            Text(L("\(count) élément(s) sélectionné(s)", "\(count) item(s) selected"))
                .foregroundStyle(.white.opacity(0.75))
            Rectangle().fill(Color.white.opacity(0.25)).frame(width: 1, height: 16)
            Text(Format.bytes(size))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.balai, value: size)

            PillButton(title: actionTitle, accent: accent, isEnabled: count > 0, action: onAction)
                .padding(.leading, 6)
        }
        .font(.system(size: 13))
    }
}

/// Bilan d'une suppression, refermable.
struct ReportRow: View {
    let report: DeletionReport
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: report.failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(report.failures.isEmpty ? Theme.success[0] : Color.orange)
            Text([report.summary, report.failureSummary].compactMap { $0 }.joined(separator: " "))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Confirmation

struct DeleteConfirmationView: View {
    let theme: Theme
    let title: String
    let count: Int
    let size: Int64
    var warning: String?
    let onConfirm: (DeletionMode) -> Void

    @AppStorage(Defaults.deletionMode) private var defaultMode: DeletionMode = .trash
    @State private var mode: DeletionMode = .trash
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            HeroArt(symbol: mode == .trash ? "trash.fill" : "flame.fill",
                    colors: mode == .trash ? theme.art : [Color(hex: 0xFF8A80), Color(hex: 0xE53935)],
                    size: 76)
                .padding(.top, 6)

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(L("\(count) élément(s) · \(Format.bytes(size))", "\(count) item(s) · \(Format.bytes(size))"))
                    .foregroundStyle(.white.opacity(0.7))
                    .monospacedDigit()
            }

            Picker("", selection: $mode) {
                ForEach(DeletionMode.allCases) { Text($0.shortLabel).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 280)

            VStack(spacing: 8) {
                Text(mode.explanation)
                    .foregroundStyle(mode == .permanent ? Color(hex: 0xFFB4AB) : .white.opacity(0.7))
                if let warning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color(hex: 0xFFC27A))
                }
            }
            .font(.system(size: 12))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                GhostButton(title: L("Annuler", "Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                PillButton(title: mode.label,
                           accent: mode == .permanent ? Color(hex: 0xE53935) : theme.accent) {
                    onConfirm(mode)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(28)
        .frame(width: 420)
        .background(ThemeBackground(theme: theme))
        .environment(\.colorScheme, .dark)
        .animation(.balai, value: mode)
        .onAppear { mode = defaultMode }
    }
}
