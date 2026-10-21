import SwiftUI
import AppKit

@main
struct BalaiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Balai") {
            ContentView()
                .frame(minWidth: 1000, minHeight: 660)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1120, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Nécessaire quand l'app est lancée avec `swift run`, hors d'un bundle .app.
        NSApp.setActivationPolicy(.regular)
        // Hors d'un bundle .app, macOS affiche l'icône générique d'un exécutable : on dessine la nôtre.
        if Bundle.main.bundleURL.pathExtension != "app", let icon = BrandIcon.image(size: 512) {
            NSApp.applicationIconImage = icon
        }
        NSApp.activate(ignoringOtherApps: true)
        #if DEBUG
        DebugSnapshot.scheduleIfRequested()
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
