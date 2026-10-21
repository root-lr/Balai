import SwiftUI

/// Barre latérale translucide, posée sur le dégradé.
struct Sidebar: View {
    @Binding var selection: Destination
    /// Taille trouvée par module, affichée à droite de son nom.
    let badge: (CleanupCategory) -> String?

    @State private var disk = DiskInfo.current()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            row(.overview, title: L("Analyse intelligente", "Smart Scan"), symbol: "sparkles")

            sectionHeader(L("Nettoyage", "Cleanup"))
            ForEach([CleanupCategory.caches, .devFiles]) { category in
                row(.module(category), title: category.title, symbol: category.symbol, badge: badge(category))
            }

            sectionHeader(L("Fichiers", "Files"))
            ForEach([CleanupCategory.spaceLens, .largeFiles]) { category in
                row(.module(category), title: category.title, symbol: category.symbol, badge: badge(category))
            }

            sectionHeader(L("Applications", "Applications"))
            row(.module(.uninstaller), title: CleanupCategory.uninstaller.title, symbol: CleanupCategory.uninstaller.symbol)

            Spacer(minLength: 16)
            diskGauge
        }
        .padding(.horizontal, 12)
        .padding(.top, 52)
        .padding(.bottom, 14)
        .frame(width: 258)
        .frame(maxHeight: .infinity)
        .background(Color.black.opacity(0.12))
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .balaiDidDelete)) { _ in disk = .current() }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.5))
            .padding(.horizontal, 10)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }

    private func row(_ destination: Destination, title: String, symbol: String, badge: String? = nil) -> some View {
        SidebarRow(title: title, symbol: symbol, badge: badge, isSelected: selection == destination) {
            selection = destination
        }
    }

    private var diskGauge: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "internaldrive")
                Text("Macintosh HD")
                Spacer()
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.85))

            GeometryReader { geo in
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.6)],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: disk.total > 0 ? geo.size.width * CGFloat(disk.used) / CGFloat(disk.total) : 0)
                    }
            }
            .frame(height: 5)

            Text(L("\(Format.bytes(disk.available)) disponibles sur \(Format.bytes(disk.total))",
                   "\(Format.bytes(disk.available)) available of \(Format.bytes(disk.total))"))
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SidebarRow: View {
    let title: String
    let symbol: String
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 14))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 4)
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(isSelected ? 0.18 : (isHovered ? 0.07 : 0)),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
