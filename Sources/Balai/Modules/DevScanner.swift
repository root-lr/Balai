import Foundation

/// Fichiers générés par les outils de développement.
struct DevScanner: Scanner {
    /// Un node_modules est pré-coché si son projet n'a pas bougé depuis ce nombre de jours.
    let staleDays: Int

    private struct Target {
        let url: URL
        let name: String
        let detail: String
        let group: String
        let risk: Risk
        let preselected: Bool
    }

    private static var xcode: String { L("Xcode et simulateurs", "Xcode & Simulators") }
    private static var packages: String { L("Gestionnaires de paquets", "Package Managers") }
    private static var nodeModules: String { L("Dossiers node_modules", "node_modules Folders") }

    private var targets: [Target] {
        [
            Target(url: Paths.lib("Developer", "Xcode", "DerivedData"), name: "DerivedData",
                   detail: L("Builds intermédiaires, régénérés à la prochaine compilation", "Intermediate builds, regenerated on next build"),
                   group: Self.xcode, risk: .safe, preselected: true),
            Target(url: Paths.lib("Developer", "Xcode", "iOS DeviceSupport"), name: "iOS DeviceSupport",
                   detail: L("Symboles d'appareils, retéléchargés au besoin", "Device symbols, downloaded again when needed"),
                   group: Self.xcode, risk: .safe, preselected: true),
            Target(url: Paths.lib("Developer", "Xcode", "watchOS DeviceSupport"), name: "watchOS DeviceSupport",
                   detail: L("Symboles d'appareils, retéléchargés au besoin", "Device symbols, downloaded again when needed"),
                   group: Self.xcode, risk: .safe, preselected: true),
            Target(url: Paths.lib("Developer", "Xcode", "tvOS DeviceSupport"), name: "tvOS DeviceSupport",
                   detail: L("Symboles d'appareils, retéléchargés au besoin", "Device symbols, downloaded again when needed"),
                   group: Self.xcode, risk: .safe, preselected: true),
            Target(url: Paths.lib("Developer", "CoreSimulator", "Caches"), name: L("Caches des simulateurs", "Simulator Caches"),
                   detail: L("Régénérés au prochain lancement d'un simulateur", "Regenerated next time a simulator starts"),
                   group: Self.xcode, risk: .safe, preselected: true),
            Target(url: Paths.lib("Developer", "Xcode", "UserData", "Previews"), name: L("Aperçus SwiftUI", "SwiftUI Previews"),
                   detail: L("Données des Previews, régénérées automatiquement", "Preview data, regenerated automatically"),
                   group: Self.xcode, risk: .safe, preselected: true),
            Target(url: Paths.lib("Developer", "Xcode", "Archives"), name: L("Archives Xcode", "Xcode Archives"),
                   detail: L("Utiles pour analyser les crashs d'apps publiées", "Useful to symbolicate crashes of shipped apps"),
                   group: Self.xcode, risk: .review, preselected: false),

            Target(url: Paths.inHome(".npm", "_cacache"), name: "Cache npm",
                   detail: "~/.npm/_cacache", group: Self.packages, risk: .safe, preselected: true),
            Target(url: Paths.inHome(".yarn", "berry", "cache"), name: "Cache Yarn",
                   detail: "~/.yarn/berry/cache", group: Self.packages, risk: .safe, preselected: true),
            Target(url: Paths.inHome(".bun", "install", "cache"), name: "Cache Bun",
                   detail: "~/.bun/install/cache", group: Self.packages, risk: .safe, preselected: true),
            Target(url: Paths.lib("pnpm", "store"), name: "Store pnpm",
                   detail: L("Partagé entre vos projets : relancez pnpm install ensuite", "Shared by your projects: run pnpm install afterwards"),
                   group: Self.packages, risk: .review, preselected: false),
            Target(url: Paths.inHome(".gradle", "caches"), name: "Cache Gradle",
                   detail: "~/.gradle/caches", group: Self.packages, risk: .safe, preselected: true),
            Target(url: Paths.inHome(".m2", "repository"), name: L("Dépôt Maven local", "Local Maven Repository"),
                   detail: L("Retéléchargé au prochain build", "Downloaded again on next build"), group: Self.packages, risk: .review, preselected: false),
            Target(url: Paths.inHome(".cargo", "registry", "cache"), name: "Cache Cargo",
                   detail: "~/.cargo/registry/cache", group: Self.packages, risk: .safe, preselected: true),
            Target(url: Paths.inHome(".cocoapods", "repos"), name: "Specs CocoaPods",
                   detail: "~/.cocoapods/repos", group: Self.packages, risk: .safe, preselected: true),
        ]
    }

    func scan(progress: @escaping @Sendable (String) -> Void) async -> [CleanupItem] {
        var result: [CleanupItem] = []
        for target in targets {
            if Task.isCancelled { return [] }
            guard FileScanning.exists(target.url) else { continue }
            progress(L("Analyse de \(target.name)…", "Scanning \(target.name)…"))
            if let item = FileScanning.makeItem(
                url: target.url, name: target.name, detail: target.detail,
                group: target.group, risk: target.risk, preselected: target.preselected
            ) {
                result.append(item)
            }
        }
        result += findNodeModules(progress: progress)
        return result
    }

    /// Cherche les node_modules dans les dossiers de projets habituels.
    private func findNodeModules(progress: @escaping @Sendable (String) -> Void) -> [CleanupItem] {
        let candidates = [
            "Developer", "Projects", "Code", "dev", "Documents", "Desktop",
            "GitHub", "src", "workspace", "Sites",
        ].map { Paths.home.appendingPathComponent($0) }

        // Le système de fichiers est insensible à la casse : ~/Projects == ~/projects.
        var seen = Set<String>()
        let roots = candidates.filter { url in
            FileScanning.isDirectory(url)
                && seen.insert(url.resolvingSymlinksInPath().path.lowercased()).inserted
        }

        let staleLimit = Date().addingTimeInterval(-Double(staleDays) * 86_400)
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        var items: [CleanupItem] = []

        for root in roots {
            progress(L("Recherche de node_modules dans ~/\(root.lastPathComponent)…", "Looking for node_modules in ~/\(root.lastPathComponent)…"))
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }

            for case let url as URL in enumerator {
                if Task.isCancelled { return [] }
                guard let values = try? url.resourceValues(forKeys: Set(keys)),
                      values.isDirectory == true, values.isSymbolicLink != true
                else { continue }

                if url.lastPathComponent == "node_modules" {
                    enumerator.skipDescendants()
                    let project = url.deletingLastPathComponent()
                    progress(L("node_modules de \(project.lastPathComponent)…", "node_modules of \(project.lastPathComponent)…"))
                    let lastActivity = FileScanning.modificationDate(of: project.appendingPathComponent("package.json"))
                        ?? FileScanning.modificationDate(of: project)
                    let isStale = (lastActivity ?? .distantPast) < staleLimit
                    if let item = FileScanning.makeItem(
                        url: url,
                        name: project.lastPathComponent,
                        detail: Format.abbreviate(project) + L(" · réinstallable avec npm install", " · reinstall with npm install"),
                        group: Self.nodeModules,
                        risk: .safe,
                        preselected: isStale
                    ) {
                        items.append(item)
                    }
                } else if enumerator.level >= 8 {
                    enumerator.skipDescendants()
                }
            }
        }
        return items.sorted { $0.size > $1.size }
    }
}
