// Exporte l'icône dessinée dans Sources/Balai/Views/BrandIcon.swift.
// Ne pas lancer directement : passer par scripts/make-icon.sh.
import SwiftUI
import AppKit

@main
struct MakeIcon {
    @MainActor
    static func main() throws {
        let resources = URL(fileURLWithPath: CommandLine.arguments[1])
        let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
        try? FileManager.default.removeItem(at: iconset)
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

        for base in [16, 32, 128, 256, 512] {
            try png(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
            try png(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
        }
        try png(size: 1024).write(to: resources.appendingPathComponent("AppIcon.png"))

        let iconutil = Process()
        iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        iconutil.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
        try iconutil.run()
        iconutil.waitUntilExit()
        print("✓ Resources/AppIcon.icns")
    }

    @MainActor
    private static func png(size: Int) -> Data {
        let renderer = ImageRenderer(content: BrandIcon(size: CGFloat(size)))
        renderer.scale = 1
        renderer.isOpaque = false
        guard let image = renderer.cgImage else { fatalError("Rendu impossible") }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
    }
}
