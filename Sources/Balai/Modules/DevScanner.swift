import Foundation

/// Fichiers générés par les outils de développement.
struct DevScanner: Scanner {
    /// Un node_modules ou une sortie de build est pré-coché si son projet n'a pas bougé depuis ce nombre de jours.
    let staleDays: Int

    private struct Target {
        let url: URL
        let name: String
        let detail: String
        let group: String
        let risk: Risk
        let preselected: Bool
        /// Outil qui sait nettoyer proprement, quand il est installé (fichiers en lecture seule…).
        var tool: (name: String, arguments: [String])?
    }

    private static var xcode: String { L("Xcode et simulateurs", "Xcode & Simulators") }
    private static var packages: String { L("Gestionnaires de paquets", "Package Managers") }
    private static var nodeModules: String { L("Dossiers node_modules", "node_modules Folders") }
    private static var buildOutputs: String { L("Sorties de build", "Build Outputs") }
    private static var homebrew: String { L("Anciennes versions Homebrew", "Old Homebrew Versions") }

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
            Target(url: Paths.inHome("go", "pkg", "mod"), name: L("Modules Go", "Go modules"),
                   detail: L("Retéléchargés au prochain build (go clean -modcache)", "Downloaded again on next build (go clean -modcache)"),
                   group: Self.packages, risk: .safe, preselected: true, tool: ("go", ["clean", "-modcache"])),
            Target(url: Paths.inHome(".cache", "uv"), name: L("Cache uv", "uv cache"),
                   detail: "~/.cache/uv", group: Self.packages, risk: .safe, preselected: true),
            Target(url: Paths.inHome("miniconda3", "pkgs"), name: L("Paquets conda (Miniconda)", "conda packages (Miniconda)"),
                   detail: L("Archives déjà installées (conda clean)", "Already-installed archives (conda clean)"),
                   group: Self.packages, risk: .safe, preselected: true),
            Target(url: Paths.inHome("anaconda3", "pkgs"), name: L("Paquets conda (Anaconda)", "conda packages (Anaconda)"),
                   detail: L("Archives déjà installées (conda clean)", "Already-installed archives (conda clean)"),
                   group: Self.packages, risk: .safe, preselected: true),
            Target(url: Paths.inHome("miniforge3", "pkgs"), name: L("Paquets conda (Miniforge)", "conda packages (Miniforge)"),
                   detail: L("Archives déjà installées (conda clean)", "Already-installed archives (conda clean)"),
                   group: Self.packages, risk: .safe, preselected: true),
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
            if var item = FileScanning.makeItem(
                url: target.url, name: target.name, detail: target.detail,
                group: target.group, risk: target.risk, preselected: target.preselected
            ) {
                if let tool = target.tool, ExternalTool.find(tool.name) != nil {
                    item.removal = .tool(tool.name, tool.arguments)
                }
                result.append(item)
            }
        }
        if Task.isCancelled { return [] }
        progress(L("Analyse des simulateurs…", "Scanning simulators…"))
        result += await simulatorItems()
        if Task.isCancelled { return [] }
        progress(L("Recherche des anciennes versions Homebrew…", "Looking for old Homebrew versions…"))
        result += await homebrewItems()
        if Task.isCancelled { return [] }
        result += findProjectArtifacts(progress: progress)
        return result
    }

    // MARK: - Simulateurs

    /// Runtimes de simulateurs (plusieurs Go chacun) et simulateurs dont le runtime a disparu, via `xcrun simctl`.
    private func simulatorItems() async -> [CleanupItem] {
        var items: [CleanupItem] = []
        let isoDate = ISO8601DateFormatter()

        if let output = await ExternalTool.run("xcrun", ["simctl", "runtime", "list", "-j"], timeout: 60), output.succeeded,
           let runtimes = try? JSONSerialization.jsonObject(with: Data(output.stdout.utf8)) as? [String: [String: Any]] {
            for (identifier, runtime) in runtimes where runtime["deletable"] as? Bool == true {
                let platform = (runtime["runtimeIdentifier"] as? String)?
                    .components(separatedBy: "SimRuntime.").last?.components(separatedBy: "-").first ?? "Simulator"
                let version = runtime["version"] as? String ?? ""
                let build = runtime["build"] as? String ?? ""
                let size = (runtime["sizeBytes"] as? NSNumber)?.int64Value ?? 0
                guard size > 0 else { continue }
                items.append(CleanupItem(
                    url: URL(string: "simctl://runtime/\(identifier)")!,
                    name: "\(platform) \(version) (\(build))",
                    detail: L("Runtime de simulateur · retéléchargeable depuis Xcode",
                              "Simulator runtime · downloadable again from Xcode"),
                    group: Self.xcode, size: size,
                    modified: (runtime["lastUsedAt"] as? String).flatMap(isoDate.date(from:)),
                    risk: .review, preselected: false,
                    removal: .tool("xcrun", ["simctl", "runtime", "delete", identifier]),
                    symbol: "iphone"))
            }
        }

        if let output = await ExternalTool.run("xcrun", ["simctl", "list", "devices", "unavailable", "-j"], timeout: 60),
           output.succeeded,
           let json = try? JSONSerialization.jsonObject(with: Data(output.stdout.utf8)) as? [String: Any],
           let byRuntime = json["devices"] as? [String: [[String: Any]]] {
            for device in byRuntime.values.flatMap({ $0 }) {
                guard let udid = device["udid"] as? String else { continue }
                let size = FileScanning.allocatedSize(of: Paths.lib("Developer", "CoreSimulator", "Devices", udid))
                items.append(CleanupItem(
                    url: URL(string: "simctl://device/\(udid)")!,
                    name: device["name"] as? String ?? udid,
                    detail: L("Simulateur dont le runtime n'est plus installé", "Simulator whose runtime is no longer installed"),
                    group: Self.xcode, size: size, modified: nil, risk: .safe, preselected: true,
                    removal: .tool("xcrun", ["simctl", "delete", udid]),
                    symbol: "iphone.slash"))
            }
        }
        return items.sorted { $0.size > $1.size }
    }

    // MARK: - Homebrew

    /// Anciennes versions conservées par Homebrew, d'après `brew cleanup --dry-run`, regroupées par formule.
    private func homebrewItems() async -> [CleanupItem] {
        guard let output = await ExternalTool.run("brew", ["cleanup", "--dry-run"], timeout: 300), output.succeeded
        else { return [] }

        var byFormula: [String: (size: Int64, versions: [String])] = [:]
        for line in output.stdout.split(separator: "\n") where line.hasPrefix("Would remove: ") {
            // « Would remove: /opt/homebrew/Cellar/openssl@3/3.3.1 (6,987 files, 33.5MB) »
            let body = line.dropFirst("Would remove: ".count)
            guard let open = body.range(of: " (") else { continue }
            let path = URL(fileURLWithPath: String(body[..<open.lowerBound]))
            let components = path.pathComponents
            guard let index = components.lastIndex(where: { $0 == "Cellar" || $0 == "Caskroom" }),
                  components.count > index + 2
            else { continue }
            let sizeText = body[open.upperBound...].split(separator: ",").last?
                .trimmingCharacters(in: CharacterSet(charactersIn: " )")) ?? ""
            let formula = components[index + 1]
            byFormula[formula, default: (0, [])].size += Format.parseSize(sizeText, base: 1024)
            byFormula[formula, default: (0, [])].versions.append(components[index + 2])
        }

        return byFormula.map { formula, info in
            CleanupItem(
                url: URL(string: "brew://formula/\(formula)")!,
                name: formula,
                detail: L("Versions remplacées : \(info.versions.joined(separator: ", "))",
                          "Replaced versions: \(info.versions.joined(separator: ", "))"),
                group: Self.homebrew, size: info.size, modified: nil, risk: .safe, preselected: true,
                removal: .tool("brew", ["cleanup", formula]), symbol: "mug.fill")
        }
        .sorted { $0.size > $1.size }
    }

    /// Dossier généré par un outil de build, reconnu au fichier qui l'accompagne dans le projet :
    /// un dossier « build » n'est retenu que si `build.gradle` est à côté, par exemple.
    private struct ArtifactRule {
        let folder: String
        let markers: [String]
        let label: String
        let rebuild: String
    }

    private static let artifactRules: [ArtifactRule] = [
        ArtifactRule(folder: "node_modules", markers: ["package.json"], label: "node_modules", rebuild: "npm install"),
        ArtifactRule(folder: "target", markers: ["Cargo.toml"], label: "Rust (target)", rebuild: "cargo build"),
        ArtifactRule(folder: ".venv", markers: ["pyproject.toml", "requirements.txt", "setup.py", "Pipfile"],
                     label: "Python (.venv)", rebuild: "uv sync / pip install"),
        ArtifactRule(folder: "venv", markers: ["pyproject.toml", "requirements.txt", "setup.py", "Pipfile"],
                     label: "Python (venv)", rebuild: "pip install"),
        ArtifactRule(folder: ".build", markers: ["Package.swift"], label: "Swift (.build)", rebuild: "swift build"),
        ArtifactRule(folder: "build", markers: ["build.gradle", "build.gradle.kts"], label: "Gradle (build)", rebuild: "gradle build"),
        ArtifactRule(folder: ".gradle", markers: ["settings.gradle", "settings.gradle.kts", "build.gradle", "build.gradle.kts"],
                     label: "Gradle (.gradle)", rebuild: "gradle build"),
        ArtifactRule(folder: ".next", markers: ["package.json"], label: "Next.js (.next)", rebuild: "next build"),
        ArtifactRule(folder: "Pods", markers: ["Podfile"], label: "CocoaPods (Pods)", rebuild: "pod install"),
        ArtifactRule(folder: ".dart_tool", markers: ["pubspec.yaml"], label: "Flutter (.dart_tool)", rebuild: "flutter pub get"),
    ]

    /// Cherche node_modules et autres sorties de build dans les dossiers de projets habituels.
    /// Pré-cochés seulement pour les projets inactifs depuis `staleDays` jours.
    private func findProjectArtifacts(progress: @escaping @Sendable (String) -> Void) -> [CleanupItem] {
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
        let rulesByFolder = Dictionary(grouping: Self.artifactRules, by: \.folder)
        var items: [CleanupItem] = []

        for root in roots {
            progress(L("Recherche des builds dans ~/\(root.lastPathComponent)…", "Looking for builds in ~/\(root.lastPathComponent)…"))
            // Pas de .skipsHiddenFiles : .venv, .build ou .next sont cachés. Les autres dossiers cachés (.git…) sont sautés.
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }

            for case let url as URL in enumerator {
                if Task.isCancelled { return [] }
                guard let values = try? url.resourceValues(forKeys: Set(keys)),
                      values.isDirectory == true, values.isSymbolicLink != true
                else { continue }

                let folder = url.lastPathComponent
                let project = url.deletingLastPathComponent()
                let rule = rulesByFolder[folder]?.first { rule in
                    rule.markers.contains { FileScanning.exists(project.appendingPathComponent($0)) }
                }

                if let rule {
                    enumerator.skipDescendants()
                    progress(L("\(rule.label) de \(project.lastPathComponent)…", "\(rule.label) of \(project.lastPathComponent)…"))
                    let marker = rule.markers.lazy.map { project.appendingPathComponent($0) }.first(where: FileScanning.exists)
                    let lastActivity = marker.flatMap(FileScanning.modificationDate(of:))
                        ?? FileScanning.modificationDate(of: project)
                    let isStale = (lastActivity ?? .distantPast) < staleLimit
                    let isNodeModules = rule.folder == "node_modules"
                    if let item = FileScanning.makeItem(
                        url: url,
                        name: project.lastPathComponent,
                        detail: isNodeModules
                            ? Format.abbreviate(project) + L(" · réinstallable avec npm install", " · reinstall with npm install")
                            : "\(Format.abbreviate(project)) · \(rule.label) · " + L("régénéré par \(rule.rebuild)", "rebuilt by \(rule.rebuild)"),
                        group: isNodeModules ? Self.nodeModules : Self.buildOutputs,
                        risk: .safe,
                        preselected: isStale
                    ) {
                        items.append(item)
                    }
                } else if folder.hasPrefix(".") || enumerator.level >= 8 {
                    enumerator.skipDescendants()
                }
            }
        }
        return items.sorted { $0.size > $1.size }
    }
}
