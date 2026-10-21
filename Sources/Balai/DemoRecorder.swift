#if DEBUG
import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Enregistre la fenêtre en GIF animé pour le README, sans autorisation d'enregistrement d'écran.
/// Le scénario qui pilote l'app est dans `ContentView.runDemo` ; voir CONTRIBUTING.md.
@MainActor
final class DemoRecorder {
    /// Images par seconde du GIF.
    private let fps: Double = 8
    /// Largeur du GIF, en pixels.
    private let width = 720

    /// L'enregistrement peut être mis en pause pendant les attentes (analyses longues).
    var isRecording = false

    private let framesDirectory: URL
    private var frameCount = 0
    private var timer: Timer?

    init() {
        framesDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("balai-demo-\(ProcessInfo.processInfo.processIdentifier)")
        try? FileManager.default.createDirectory(at: framesDirectory, withIntermediateDirectories: true)
        timer = Timer.scheduledTimer(withTimeInterval: 1 / fps, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.captureFrame() }
        }
    }

    private func captureFrame() {
        guard isRecording, let image = DebugSnapshot.captureMainWindow(), let scaled = scale(image) else { return }
        let url = framesDirectory.appendingPathComponent(String(format: "%05d.png", frameCount))
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(destination, scaled, nil)
        if CGImageDestinationFinalize(destination) { frameCount += 1 }
    }

    private func scale(_ image: CGImage) -> CGImage? {
        let height = Int(Double(image.height) * Double(width) / Double(image.width))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// Assemble les images en GIF qui tourne en boucle.
    func writeGIF(to output: URL) {
        timer?.invalidate()
        guard frameCount > 0,
              let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString,
                                                                frameCount, nil)
        else { return }
        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0],
        ] as CFDictionary)
        let frameProperties = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps],
        ] as CFDictionary

        for index in 0..<frameCount {
            let url = framesDirectory.appendingPathComponent(String(format: "%05d.png", index))
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else { continue }
            CGImageDestinationAddImage(destination, image, frameProperties)
        }
        CGImageDestinationFinalize(destination)
        try? FileManager.default.removeItem(at: framesDirectory)
    }
}
#endif
