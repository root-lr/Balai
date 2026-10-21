import SwiftUI

/// Écran affiché à droite de la barre latérale.
enum Destination: Hashable {
    case overview
    case module(CleanupCategory)
}

/// Ambiance d'un écran : dégradé de fond, accent des boutons et couleurs de l'illustration.
struct Theme {
    let top: Color
    let bottom: Color
    let accent: Color
    let art: [Color]

    static let overview = Theme(top: Color(hex: 0xA2549B), bottom: Color(hex: 0x2E3A8F),
                                accent: Color(hex: 0xFF5FA2), art: [Color(hex: 0xFF8AC8), Color(hex: 0xD9408F)])
    static let success = [Color(hex: 0x86F2B4), Color(hex: 0x1FB36B)]
}

extension Destination {
    var theme: Theme {
        switch self {
        case .overview: return .overview
        case .module(let category): return category.theme
        }
    }
}

extension CleanupCategory {
    var theme: Theme {
        switch self {
        case .caches:
            return Theme(top: Color(hex: 0x1F9C8A), bottom: Color(hex: 0x1D3A6B),
                         accent: Color(hex: 0x3BE0B0), art: [Color(hex: 0x6BF0C8), Color(hex: 0x1FA98A)])
        case .devFiles:
            return Theme(top: Color(hex: 0xC0612E), bottom: Color(hex: 0x4A2459),
                         accent: Color(hex: 0xFFB257), art: [Color(hex: 0xFFC56B), Color(hex: 0xF07A2A)])
        case .largeFiles:
            return Theme(top: Color(hex: 0x7A3FC2), bottom: Color(hex: 0x2B1B66),
                         accent: Color(hex: 0xE066FF), art: [Color(hex: 0xD89BFF), Color(hex: 0x8A3FE0)])
        case .uninstaller:
            return Theme(top: Color(hex: 0x2F6FD6), bottom: Color(hex: 0x1B2863),
                         accent: Color(hex: 0x5CC8FF), art: [Color(hex: 0x7FD4FF), Color(hex: 0x2F7BE8)])
        case .spaceLens:
            return Theme(top: Color(hex: 0x5B2A9E), bottom: Color(hex: 0x1C1050),
                         accent: Color(hex: 0xFF4FD8), art: [Color(hex: 0xFF9BEA), Color(hex: 0xB03FE0)])
        case .containers:
            return Theme(top: Color(hex: 0x1D63ED), bottom: Color(hex: 0x0B2A5C),
                         accent: Color(hex: 0x4FC3F7), art: [Color(hex: 0x7FD8FF), Color(hex: 0x1D63ED)])
        case .aiModels:
            return Theme(top: Color(hex: 0x3A47D5), bottom: Color(hex: 0x12123A),
                         accent: Color(hex: 0x00D2FF), art: [Color(hex: 0x8EE8FF), Color(hex: 0x3A47D5)])
        case .virtualMachines:
            return Theme(top: Color(hex: 0x475569), bottom: Color(hex: 0x0F172A),
                         accent: Color(hex: 0x94A3B8), art: [Color(hex: 0xCBD5E1), Color(hex: 0x64748B)])
        case .devices:
            return Theme(top: Color(hex: 0xDB2777), bottom: Color(hex: 0x4A0D2E),
                         accent: Color(hex: 0xF9A8D4), art: [Color(hex: 0xFBCFE8), Color(hex: 0xDB2777)])
        case .duplicates:
            return Theme(top: Color(hex: 0x4D7C0F), bottom: Color(hex: 0x14290A),
                         accent: Color(hex: 0xA3E635), art: [Color(hex: 0xD9F99D), Color(hex: 0x65A30D)])
        case .orphans:
            return Theme(top: Color(hex: 0xB91C1C), bottom: Color(hex: 0x3F0A12),
                         accent: Color(hex: 0xFCA5A5), art: [Color(hex: 0xFECACA), Color(hex: 0xDC2626)])
        case .startupItems:
            return Theme(top: Color(hex: 0x0E7490), bottom: Color(hex: 0x082F49),
                         accent: Color(hex: 0x67E8F9), art: [Color(hex: 0xA5F3FC), Color(hex: 0x0891B2)])
        }
    }

    /// Variante pleine du symbole, pour les illustrations.
    var artSymbol: String {
        switch self {
        case .caches: return "archivebox.fill"
        case .devFiles: return "hammer.fill"
        case .largeFiles: return "doc.fill"
        case .uninstaller: return "xmark.app.fill"
        case .spaceLens: return "circle.hexagongrid.fill"
        case .containers: return "shippingbox.fill"
        case .aiModels: return "brain"
        case .virtualMachines: return "desktopcomputer"
        case .devices: return "iphone"
        case .duplicates: return "doc.on.doc.fill"
        case .orphans: return "puzzlepiece.fill"
        case .startupItems: return "power"
        }
    }
}

extension Animation {
    static let balai = Animation.spring(response: 0.38, dampingFraction: 0.86)
}

extension View {
    /// Panneau translucide posé sur le dégradé.
    func panel(cornerRadius: CGFloat = 16) -> some View {
        background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Fond

struct ThemeBackground: View {
    let theme: Theme

    var body: some View {
        ZStack {
            LinearGradient(colors: [theme.top, theme.bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.white.opacity(0.16), .clear],
                           center: UnitPoint(x: 0.65, y: 0), startRadius: 0, endRadius: 700)
        }
    }
}

// MARK: - Illustration

/// Grande tuile brillante qui illustre un écran.
struct HeroArt: View {
    let symbol: String
    let colors: [Color]
    var size: CGFloat = 190
    var isAnimating = false

    @State private var isUp = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center))
                .padding(2)
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.22), radius: 8, y: 6)
        }
        .frame(width: size, height: size)
        .shadow(color: (colors.last ?? .black).opacity(0.55), radius: 34, y: 20)
        .offset(y: isUp ? -8 : 0)
        .onAppear { if isAnimating { float() } }
    }

    private func float() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { isUp = true }
    }
}

// MARK: - Boutons

/// Gros bouton rond, la signature de l'app.
struct ScanButton: View {
    let title: String
    let accent: Color
    var isBusy = false
    var isEnabled = true
    let action: () -> Void

    @State private var isHovered = false
    @State private var isSpinning = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0.08)],
                                         startPoint: .top, endPoint: .bottom))
                Circle()
                    .strokeBorder(LinearGradient(colors: [accent, accent.opacity(0.35)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 3)
                if isBusy {
                    Circle()
                        .trim(from: 0, to: 0.28)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .padding(1.5)
                        .rotationEffect(.degrees(isSpinning ? 360 : 0))
                        .onAppear {
                            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { isSpinning = true }
                        }
                        .onDisappear { isSpinning = false }
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(8)
            }
            .frame(width: 100, height: 100)
            .shadow(color: accent.opacity(isHovered && isEnabled ? 0.8 : 0.45), radius: isHovered ? 28 : 16)
            .scaleEffect(isHovered && isEnabled ? 1.04 : 1)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .onHover { hovering in withAnimation(.balai) { isHovered = hovering } }
    }
}

/// Bouton principal en capsule colorée (« Nettoyer », « Désinstaller »).
struct PillButton: View {
    let title: String
    let accent: Color
    var systemImage: String?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).lineLimit(1)
            }
            .fixedSize()
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                // Un peu plus sombre que l'accent, pour que le texte blanc reste lisible.
                Capsule()
                    .fill(LinearGradient(colors: [accent, accent.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                    .brightness(-0.14)
            )
            .shadow(color: accent.opacity(0.45), radius: 10, y: 4)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

/// Bouton secondaire discret, en capsule translucide.
struct GhostButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.white.opacity(isHovered ? 0.2 : 0.12), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Mise en page

/// Écran centré : illustration, titre, texte, puis action principale en bas.
struct HeroPage<Art: View, Extra: View, Action: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var art: Art
    @ViewBuilder var extra: Extra
    @ViewBuilder var action: Action

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            art
            Spacer().frame(height: 40)
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: 480)
                .padding(.top, 8)
            extra
                .padding(.top, 18)
            Spacer(minLength: 24)
            action
            Spacer().frame(height: 40)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
