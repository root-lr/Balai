import SwiftUI

/// Contenu d'un dossier en bulles, dont l'aire est proportionnelle à la taille.
struct BubbleChart: View {
    let node: DiskNode
    let accent: Color
    let isSelected: (DiskNode) -> Bool
    let onTap: (DiskNode) -> Void

    /// Au-delà, les éléments rejoignent la bulle « Autres éléments ».
    private static let maxBubbles = 14

    var body: some View {
        let shown = Array(node.children.prefix(Self.maxBubbles))
        let rest = node.children.dropFirst(Self.maxBubbles)
        let otherSize = node.otherSize + rest.reduce(0) { $0 + $1.size }
        let otherCount = node.otherCount + rest.count
        let values = shown.map { Double($0.size) } + (otherSize > 0 ? [Double(otherSize)] : [])

        GeometryReader { geo in
            let circles = BubbleLayout.pack(values, in: geo.size)
            ZStack {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, child in
                    if index < circles.count {
                        NodeBubble(node: child, diameter: circles[index].radius * 2, accent: accent,
                                   isSelected: isSelected(child)) { onTap(child) }
                            .position(x: circles[index].x, y: circles[index].y)
                    }
                }
                if otherSize > 0, let circle = circles.last, circles.count == shown.count + 1 {
                    OtherBubble(count: otherCount, size: otherSize, diameter: circle.radius * 2)
                        .position(x: circle.x, y: circle.y)
                }
            }
        }
    }
}

private struct NodeBubble: View {
    let node: DiskNode
    let diameter: CGFloat
    let accent: Color
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(0.24), accent.opacity(0.14)],
                                         center: UnitPoint(x: 0.35, y: 0.25), startRadius: 0, endRadius: diameter * 0.75))
                Circle()
                    .strokeBorder(accent.opacity(isSelected ? 1 : 0.55), lineWidth: isSelected ? 4 : 1.5)
                if diameter > 44 {
                    VStack(spacing: 3) {
                        if diameter > 84 {
                            FileIcon(url: node.url, size: min(diameter * 0.3, 54))
                        }
                        if diameter > 64 {
                            Text(node.name)
                                .font(.system(size: min(13, diameter / 8), weight: .semibold))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Text(Format.bytes(node.size))
                            .font(.system(size: min(12, diameter / 7)))
                            .monospacedDigit()
                            .opacity(0.85)
                    }
                    .foregroundStyle(.white)
                    .padding(diameter * 0.16)
                }
            }
            .frame(width: diameter, height: diameter)
            .shadow(color: accent.opacity(isHovered ? 0.6 : 0.25), radius: isHovered ? 18 : 8)
            .scaleEffect(isHovered ? 1.04 : 1)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(.balai) { isHovered = hovering } }
        .help("\(node.url.path) — \(Format.bytes(node.size))")
    }
}

private struct OtherBubble: View {
    let count: Int
    let size: Int64
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.08))
            Circle().strokeBorder(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            if diameter > 56 {
                VStack(spacing: 2) {
                    Text(L("Autres éléments", "Other items"))
                        .font(.system(size: min(12, diameter / 8), weight: .medium))
                    Text(Format.bytes(size)).font(.system(size: min(11, diameter / 8))).opacity(0.75)
                }
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(diameter * 0.12)
            }
        }
        .frame(width: diameter, height: diameter)
        .help(L("\(count) éléments plus petits", "\(count) smaller items"))
    }
}

/// Placement glouton de cercles : chaque bulle se colle à une bulle déjà placée,
/// au plus près du centre, puis l'ensemble est mis à l'échelle de la zone.
enum BubbleLayout {
    struct Circle {
        var x: CGFloat
        var y: CGFloat
        var radius: CGFloat
    }

    static func pack(_ values: [Double], in size: CGSize) -> [Circle] {
        guard let largest = values.max(), largest > 0, size.width > 0, size.height > 0 else { return [] }
        // Les plus petites bulles gardent une taille lisible.
        let radii = values.map { CGFloat(max(sqrt($0 / largest), 0.2)) }
        let gap: CGFloat = 0.05
        let aspect = size.width / size.height

        var placed: [Circle] = []
        for radius in radii {
            guard !placed.isEmpty else {
                placed.append(Circle(x: 0, y: 0, radius: radius))
                continue
            }
            var best: Circle?
            var bestDistance = CGFloat.infinity
            for anchor in placed {
                for step in 0..<48 {
                    let angle = CGFloat(step) / 48 * 2 * .pi
                    let distance = anchor.radius + radius + gap
                    let candidate = Circle(x: anchor.x + cos(angle) * distance,
                                           y: anchor.y + sin(angle) * distance, radius: radius)
                    let overlaps = placed.contains {
                        hypot($0.x - candidate.x, $0.y - candidate.y) < $0.radius + radius + gap - 0.001
                    }
                    guard !overlaps else { continue }
                    // On étire vers la largeur, la zone étant plus large que haute.
                    let score = hypot(candidate.x / aspect, candidate.y)
                    if score < bestDistance {
                        bestDistance = score
                        best = candidate
                    }
                }
            }
            if let best { placed.append(best) }
        }

        let minX = placed.map { $0.x - $0.radius }.min()!
        let maxX = placed.map { $0.x + $0.radius }.max()!
        let minY = placed.map { $0.y - $0.radius }.min()!
        let maxY = placed.map { $0.y + $0.radius }.max()!
        let scale = min(size.width / (maxX - minX), size.height / (maxY - minY)) * 0.94
        let midX = (minX + maxX) / 2
        let midY = (minY + maxY) / 2
        return placed.map {
            Circle(x: ($0.x - midX) * scale + size.width / 2,
                   y: ($0.y - midY) * scale + size.height / 2,
                   radius: $0.radius * scale)
        }
    }
}
