import Foundation

/// Agents lancés à l'ouverture de la session (~/Library/LaunchAgents).
/// Ceux dont le programme a disparu sont pré-cochés : ils échouent à chaque connexion sans rien faire.
/// Les agents installés pour tout le Mac (/Library) demandent des droits d'administrateur : ils ne sont pas proposés.
struct StartupScanner: Scanner {
    private static let directory = Paths.lib("LaunchAgents")

    func scan(progress: @escaping @Sendable (String) -> Void) async -> [CleanupItem] {
        progress(L("Lecture des agents de lancement…", "Reading launch agents…"))
        let items = FileScanning.children(of: Self.directory)
            .filter { $0.pathExtension == "plist" }
            .compactMap(item(for:))
        // Les agents orphelins d'abord.
        return items.sorted { $0.preselected != $1.preselected ? $0.preselected : $0.name < $1.name }
    }

    private func item(for plist: URL) -> CleanupItem? {
        guard let info = NSDictionary(contentsOf: plist) as? [String: Any],
              let label = info["Label"] as? String
        else { return nil }

        let program = info["Program"] as? String ?? (info["ProgramArguments"] as? [String])?.first
        let programExists = program.map { FileManager.default.fileExists(atPath: $0) } ?? false
        let appName = program.flatMap(Self.appName(containing:))

        var detail: String
        if let program, !programExists {
            detail = L("Programme introuvable : \(program)", "Program not found: \(program)")
        } else if let program {
            detail = Format.abbreviate(URL(fileURLWithPath: program))
        } else {
            detail = label
        }
        if info["Disabled"] as? Bool == true {
            detail += L(" · désactivé", " · disabled")
        }

        guard var item = FileScanning.makeItem(
            url: plist, name: appName ?? label, detail: detail,
            group: programExists ? L("Agents de vos apps", "Your Apps' Agents")
                                 : L("Programme disparu", "Program Gone"),
            risk: programExists ? .review : .safe, preselected: !programExists
        ) else { return nil }
        item.removal = .launchAgent(label: label)
        item.symbol = programExists ? "power" : "bolt.slash.fill"
        return item
    }

    /// « /Applications/Foo.app/Contents/MacOS/helper » → « Foo ».
    private static func appName(containing path: String) -> String? {
        let components = URL(fileURLWithPath: path).pathComponents
        guard let app = components.first(where: { $0.hasSuffix(".app") }) else { return nil }
        return String(app.dropLast(4))
    }
}
