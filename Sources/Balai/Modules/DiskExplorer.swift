import Foundation

/// Un fichier ou un dossier de l'explorateur d'espace.
/// L'arbre est construit en arrière-plan, puis n'est plus modifié que sur le thread principal
/// (retrait des éléments supprimés).
final class DiskNode: Identifiable, @unchecked Sendable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let isPackage: Bool
    /// Dossier illisible (permissions) : sa taille réelle est inconnue.
    let isRestricted: Bool
    var size: Int64
    /// Enfants les plus lourds, du plus gros au plus petit.
    var children: [DiskNode]
    /// Éléments trop petits pour être listés un par un.
    var otherCount: Int
    var otherSize: Int64
    weak var parent: DiskNode?

    var id: URL { url }
    var itemCount: Int { children.count + otherCount }
    var canOpen: Bool { isDirectory && !isPackage && itemCount > 0 }

    init(url: URL, name: String, isDirectory: Bool, isPackage: Bool, isRestricted: Bool = false,
         size: Int64, children: [DiskNode] = [], otherCount: Int = 0, otherSize: Int64 = 0) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.isPackage = isPackage
        self.isRestricted = isRestricted
        self.size = size
        self.children = children
        self.otherCount = otherCount
        self.otherSize = otherSize
    }
}

/// Analyse de tout le disque de démarrage : volume système, volume de données et volumes annexes
/// (swap, Preboot, mises à jour…). Les disques externes et réseau sont ignorés.
enum DiskExplorer {
    /// Nombre d'enfants gardés par dossier ; les autres sont regroupés.
    private static let keptChildren = 40

    private static let resourceKeys: [URLResourceKey] = [
        .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
    ]

    /// Chemins à ne pas parcourir : montages externes et pseudo-systèmes de fichiers, plus,
    /// dans le volume de données, tout ce qui est déjà visible depuis « / » via un firmlink
    /// (sinon /Users, /Applications… seraient comptés deux fois).
    private static let skippedPaths: Set<String> = {
        var paths: Set<String> = [
            "/Volumes", "/dev", "/net", "/home", "/.vol", "/.nofollow", "/.resolve",
            "/System/Volumes/Data/Volumes", "/System/Volumes/Data/home",
        ]
        let firmlinks = (try? String(contentsOfFile: "/usr/share/firmlinks", encoding: .utf8)) ?? ""
        for line in firmlinks.split(separator: "\n") {
            guard let target = line.split(separator: "\t").last else { continue }
            paths.insert("/System/Volumes/Data/" + target)
        }
        return paths
    }()

    static func scan(progress: @escaping @Sendable (_ path: String, _ files: Int) -> Void) async -> DiskNode {
        let counter = ProgressCounter(report: progress)
        let root = URL(fileURLWithPath: "/", isDirectory: true)
        let name = FileManager.default.displayName(atPath: "/")
        let node = await scanDirectory(root, name: name, isPackage: false, depth: 0, counter: counter)
        link(node)
        return node
    }

    // MARK: - Parcours

    /// Les premiers niveaux sont parcourus en parallèle, le reste séquentiellement.
    private static func scanDirectory(_ url: URL, name: String, isPackage: Bool, depth: Int,
                                      counter: ProgressCounter) async -> DiskNode {
        guard depth < 3 else { return scanDirectorySync(url, name: name, isPackage: isPackage, counter: counter) }
        guard let listing = list(url, counter: counter) else { return restricted(url, name: name, isPackage: isPackage) }

        let subdirectories = await withTaskGroup(of: DiskNode.self) { group in
            for entry in listing.directories {
                group.addTask {
                    await scanDirectory(entry.url, name: entry.url.lastPathComponent, isPackage: entry.isPackage,
                                        depth: depth + 1, counter: counter)
                }
            }
            var nodes: [DiskNode] = []
            for await node in group { nodes.append(node) }
            return nodes
        }
        return makeNode(url, name: name, isPackage: isPackage, directories: subdirectories, files: listing.files)
    }

    private static func scanDirectorySync(_ url: URL, name: String, isPackage: Bool, counter: ProgressCounter) -> DiskNode {
        guard let listing = list(url, counter: counter) else { return restricted(url, name: name, isPackage: isPackage) }
        let subdirectories = listing.directories.map {
            scanDirectorySync($0.url, name: $0.url.lastPathComponent, isPackage: $0.isPackage, counter: counter)
        }
        return makeNode(url, name: name, isPackage: isPackage, directories: subdirectories, files: listing.files)
    }

    private struct Listing {
        var directories: [(url: URL, isPackage: Bool)] = []
        var files: [(url: URL, size: Int64)] = []
    }

    /// Contenu direct d'un dossier, ou nil s'il est illisible.
    private static func list(_ url: URL, counter: ProgressCounter) -> Listing? {
        if Task.isCancelled { return Listing() }
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: resourceKeys, options: []
        ) else { return nil }

        var listing = Listing()
        for entry in entries {
            guard let values = try? entry.resourceValues(forKeys: Set(resourceKeys)),
                  values.isSymbolicLink != true
            else { continue }
            if values.isDirectory == true {
                // Certains chemins arrivent avec une barre finale (« /.nofollow/ ») : on la retire avant de comparer.
                var path = entry.path
                while path.count > 1 && path.hasSuffix("/") { path.removeLast() }
                if !skippedPaths.contains(path) {
                    listing.directories.append((entry, values.isPackage == true))
                }
            } else {
                listing.files.append((entry, Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)))
            }
        }
        counter.add(listing.files.count, in: url)
        return listing
    }

    /// Garde les plus gros enfants et regroupe les autres.
    private static func makeNode(_ url: URL, name: String, isPackage: Bool,
                                 directories: [DiskNode], files: [(url: URL, size: Int64)]) -> DiskNode {
        var candidates: [(size: Int64, node: () -> DiskNode)] = directories.map { node in (node.size, { node }) }
        candidates += files.map { file in
            (file.size, { DiskNode(url: file.url, name: file.url.lastPathComponent, isDirectory: false,
                                   isPackage: false, size: file.size) })
        }
        candidates.sort { $0.size > $1.size }

        let total = candidates.reduce(0) { $0 + $1.size }
        let kept = candidates.prefix(keptChildren).filter { $0.size > 0 }.map { $0.node() }
        let keptSize = kept.reduce(0) { $0 + $1.size }
        return DiskNode(url: url, name: name, isDirectory: true, isPackage: isPackage, size: total,
                        children: kept, otherCount: candidates.count - kept.count, otherSize: total - keptSize)
    }

    private static func restricted(_ url: URL, name: String, isPackage: Bool) -> DiskNode {
        DiskNode(url: url, name: name, isDirectory: true, isPackage: isPackage, isRestricted: true, size: 0)
    }

    private static func link(_ node: DiskNode) {
        for child in node.children {
            child.parent = node
            link(child)
        }
    }
}

/// Compte les fichiers vus et remonte la progression de temps en temps.
private final class ProgressCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var files = 0
    private var lastReport = 0
    private let report: @Sendable (String, Int) -> Void

    init(report: @escaping @Sendable (String, Int) -> Void) {
        self.report = report
    }

    func add(_ count: Int, in directory: URL) {
        lock.lock()
        files += count
        let total = files
        let shouldReport = total - lastReport >= 2_000
        if shouldReport { lastReport = total }
        lock.unlock()
        if shouldReport { report(directory.path, total) }
    }
}
