import SwiftUI
import AppKit

// Logo de Balai, dessiné en code. Ce fichier ne dépend que de SwiftUI :
// scripts/make-icon.sh le compile aussi pour produire Resources/AppIcon.icns.

/// Icône de l'app à la taille voulue.
struct BrandIcon: View {
    var size: CGFloat = 1024

    var body: some View {
        BrandIconArt()
            .frame(width: 1024, height: 1024)
            .scaleEffect(size / 1024)
            .frame(width: size, height: size)
    }

    /// Rendu bitmap, pour l'icône du Dock quand l'app tourne hors d'un bundle .app.
    @MainActor
    static func image(size: CGFloat) -> NSImage? {
        let renderer = ImageRenderer(content: BrandIcon(size: size))
        renderer.scale = 2
        renderer.isOpaque = false
        return renderer.nsImage
    }
}

/// Dessin sur un canevas de 1024 × 1024, selon la grille d'icône macOS (corps de 824 px).
struct BrandIconArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x5AC8FA), Color(hex: 0x2F6BFF), Color(hex: 0x4B2BD1)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    // Reflet doux en haut
                    RoundedRectangle(cornerRadius: 185, style: .continuous)
                        .fill(RadialGradient(colors: [.white.opacity(0.35), .clear],
                                             center: UnitPoint(x: 0.3, y: 0.0), startRadius: 0, endRadius: 620))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 185, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 3)
                )
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.28), radius: 20, x: 0, y: 12)

            BroomGlyph()
                .rotationEffect(.degrees(32))
                .offset(x: 40, y: 30)

            Group {
                Sparkle().frame(width: 150, height: 150).offset(x: -180, y: -190)
                Sparkle().frame(width: 74, height: 74).offset(x: -60, y: -290)
                Sparkle().frame(width: 52, height: 52).offset(x: -280, y: -60)
            }
            .foregroundStyle(.white)
            .shadow(color: Color(hex: 0x0B1A6B).opacity(0.25), radius: 12, x: 0, y: 6)
        }
    }
}

private struct BroomGlyph: View {
    var body: some View {
        ZStack(alignment: .top) {
            // Manche
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: 0xFFFFFF), Color(hex: 0xDCE6FF)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 58, height: 430)

            // Bague
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xFF8A65), Color(hex: 0xF4511E)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 148, height: 58)
                .offset(y: 392)

            // Tête
            ZStack {
                BroomHead()
                    .fill(LinearGradient(colors: [Color(hex: 0xFFE082), Color(hex: 0xFFB300)],
                                         startPoint: .top, endPoint: .bottom))
                Bristles()
                    .stroke(Color(hex: 0xE08E00).opacity(0.55), style: StrokeStyle(lineWidth: 9, lineCap: .round))
            }
            .frame(width: 330, height: 270)
            .offset(y: 440)
        }
        .frame(width: 330, height: 710, alignment: .top)
        .shadow(color: Color(hex: 0x0B1A6B).opacity(0.35), radius: 24, x: 0, y: 18)
    }
}

/// Étincelle à quatre branches.
struct Sparkle: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = rect.width / 2
        let k = r * 0.16
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        return p
    }
}

/// Tête de balai : trapèze au bas arrondi.
private struct BroomHead: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = rect.width * 0.24
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.12))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.12),
            control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.12)
        )
        p.closeSubpath()
        return p
    }
}

/// Brins : lignes qui s'écartent depuis le haut de la tête.
private struct Bristles: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let count = 6
        for i in 1..<count {
            let t = CGFloat(i) / CGFloat(count)
            let top = CGPoint(x: rect.minX + rect.width * (0.24 + 0.52 * t), y: rect.minY + rect.height * 0.18)
            let bottomX = rect.minX + rect.width * t
            let sag = 4 * t * (1 - t) * rect.height * 0.12
            let bottom = CGPoint(x: bottomX, y: rect.maxY - rect.height * 0.2 + sag)
            p.move(to: top)
            p.addLine(to: bottom)
        }
        return p
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
