#if DEBUG
import AppKit

/// Capture de la fenêtre pour le développement, sans autorisation d'enregistrement d'écran.
/// Usage : BALAI_SNAPSHOT=/tmp/shot.png [BALAI_SNAPSHOT_DELAY=4] swift run
enum DebugSnapshot {
    static func scheduleIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["BALAI_SNAPSHOT"] else { return }
        let delay = Double(env["BALAI_SNAPSHOT_DELAY"] ?? "") ?? 3

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if let image = captureMainWindow() {
                let rep = NSBitmapImageRep(cgImage: image)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            }
            exit(0)
        }
    }

    static func captureMainWindow() -> CGImage? {
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }) else { return nil }
        return capture(windowID: CGWindowID(window.windowNumber))
    }

    /// CGWindowListCreateImage n'est plus exposé par le SDK, mais reste utilisable pour ses propres fenêtres.
    private static func capture(windowID: CGWindowID) -> CGImage? {
        typealias Fn = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") else { return nil }
        let create = unsafeBitCast(symbol, to: Fn.self)
        // optionIncludingWindow = 1 << 3 ; boundsIgnoreFraming = 1 << 0, bestResolution = 1 << 3
        return create(.null, 1 << 3, windowID, (1 << 0) | (1 << 3))?.takeRetainedValue()
    }
}
#endif
