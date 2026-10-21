import AppKit

enum Permissions {
    /// Vrai si l'app a l'« Accès complet au disque ».
    /// macOS n'applique ce droit qu'au lancement : après l'avoir accordé, il faut relancer l'app.
    static let hasFullDiskAccess: Bool = {
        let probes = [
            "/Library/Application Support/com.apple.TCC/TCC.db",
            Paths.lib("Safari", "Bookmarks.plist").path,
        ]
        return probes.contains { FileHandle(forReadingAtPath: $0) != nil }
    }()

    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
