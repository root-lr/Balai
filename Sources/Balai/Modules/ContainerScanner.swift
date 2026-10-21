import Foundation

/// Docker (Docker Desktop, OrbStack, Colima…) et clusters Kubernetes locaux.
/// Tout vit dans la machine virtuelle du moteur : on passe par les commandes `docker`, `minikube`, `kind`
/// et `k3d`, jamais par les fichiers (supprimer le disque de la VM effacerait tout d'un coup).
struct ContainerScanner: Scanner {
    private static var cacheGroup: String { L("Cache de build", "Build Cache") }
    private static var containersGroup: String { L("Conteneurs arrêtés", "Stopped Containers") }
    private static var imagesGroup: String { L("Images inutilisées", "Unused Images") }
    private static var volumesGroup: String { L("Volumes inutilisés", "Unused Volumes") }
    private static var clustersGroup: String { L("Clusters Kubernetes locaux", "Local Kubernetes Clusters") }

    private static let clusterTools = ["minikube", "kind", "k3d"]

    func unavailableReason() async -> String? {
        let hasClusterTools = Self.clusterTools.contains { ExternalTool.find($0) != nil }
        guard ExternalTool.find("docker") != nil else {
            return hasClusterTools ? nil : L(
                "Aucun outil de conteneurs trouvé : installez Docker Desktop, OrbStack ou Colima.",
                "No container tool found: install Docker Desktop, OrbStack or Colima.")
        }
        let engine = await ExternalTool.run("docker", ["info", "--format", "{{.ServerVersion}}"], timeout: 20)
        if engine?.succeeded != true && !hasClusterTools {
            return L("Docker n'est pas lancé : ouvrez Docker Desktop, OrbStack ou Colima, puis relancez l'analyse.",
                     "Docker isn't running: open Docker Desktop, OrbStack or Colima, then scan again.")
        }
        return nil
    }

    func scan(progress: @escaping @Sendable (String) -> Void) async -> [CleanupItem] {
        var items: [CleanupItem] = []
        progress(L("Interrogation de Docker…", "Asking Docker…"))
        items += await dockerItems()
        if Task.isCancelled { return [] }
        progress(L("Recherche des clusters Kubernetes…", "Looking for Kubernetes clusters…"))
        items += await clusterItems()
        return items
    }

    // MARK: - Docker

    private func dockerItems() async -> [CleanupItem] {
        guard let output = await ExternalTool.run("docker", ["system", "df", "-v", "--format", "{{json .}}"], timeout: 120),
              output.succeeded,
              let json = try? JSONSerialization.jsonObject(with: Data(output.stdout.utf8)) as? [String: Any]
        else { return [] }

        let engine = await ExternalTool.run("docker", ["info", "--format", "{{.OperatingSystem}}"], timeout: 20)
        let engineName = engine?.succeeded == true ? engine!.stdout.trimmingCharacters(in: .whitespacesAndNewlines) : "Docker"

        func rows(_ key: String) -> [[String: Any]] { json[key] as? [[String: Any]] ?? [] }
        func text(_ row: [String: Any], _ key: String) -> String { row[key] as? String ?? "" }

        var items: [CleanupItem] = []

        // Cache de build : tout ce qui n'est pas en cours d'utilisation se reconstruit au prochain build.
        let unusedCache = rows("BuildCache").filter { text($0, "InUse") != "true" }
        let cacheSize = unusedCache.reduce(Int64(0)) { $0 + Format.parseSize(text($1, "Size")) }
        if cacheSize > 0 {
            items.append(CleanupItem(
                url: URL(string: "docker://build-cache")!,
                name: L("Cache de build", "Build cache"),
                detail: L("\(engineName) · \(unusedCache.count) entrées · se reconstruit au prochain build",
                          "\(engineName) · \(unusedCache.count) entries · rebuilt on next build"),
                group: Self.cacheGroup, size: cacheSize, modified: nil, risk: .safe, preselected: true,
                removal: .tool("docker", ["builder", "prune", "--all", "--force"], order: 3),
                symbol: "hammer.fill"))
        }

        // Conteneurs arrêtés : ceux qui tournent ne sont jamais proposés.
        for row in rows("Containers") where !["running", "restarting", "paused"].contains(text(row, "State")) {
            let id = text(row, "ID")
            items.append(CleanupItem(
                url: URL(string: "docker://container/\(id)")!,
                name: text(row, "Names"),
                detail: "\(text(row, "Image")) · \(text(row, "Status"))",
                group: Self.containersGroup, size: Format.parseSize(text(row, "Size")), modified: nil,
                risk: .review, preselected: false,
                removal: .tool("docker", ["rm", id], order: 0),
                symbol: "shippingbox.fill"))
        }

        // Images : seules celles qu'aucun conteneur n'utilise peuvent partir.
        for row in rows("Images") where text(row, "Containers") == "0" {
            let id = text(row, "ID")
            let repository = text(row, "Repository")
            let isDangling = repository == "<none>"
            let shortID = id.replacingOccurrences(of: "sha256:", with: "").prefix(12)
            items.append(CleanupItem(
                url: URL(string: "docker://image/\(id)")!,
                name: isDangling ? L("Image sans nom (\(shortID))", "Untagged image (\(shortID))")
                                 : "\(repository):\(text(row, "Tag"))",
                detail: isDangling
                    ? L("Couche orpheline d'un ancien build", "Leftover layer from an old build")
                    : L("Créée \(text(row, "CreatedSince")) · à retélécharger si besoin",
                        "Created \(text(row, "CreatedSince")) · pulled again when needed"),
                group: Self.imagesGroup, size: Format.parseSize(text(row, "Size")), modified: nil,
                risk: isDangling ? .safe : .review, preselected: isDangling,
                removal: .tool("docker", ["rmi", id], order: 1),
                symbol: "square.stack.3d.up.fill"))
        }

        // Volumes : ce sont des données (bases, fichiers…). Jamais pré-cochés, et seulement s'ils ne sont plus rattachés.
        for row in rows("Volumes") where text(row, "Links") == "0" {
            let name = text(row, "Name")
            let isAnonymous = text(row, "Labels").contains("com.docker.volume.anonymous")
            items.append(CleanupItem(
                url: URL(string: "docker://volume/\(name)")!,
                name: isAnonymous ? L("Volume anonyme (\(name.prefix(12)))", "Anonymous volume (\(name.prefix(12)))") : name,
                detail: L("Données (base de données, fichiers…) : vérifiez avant de supprimer",
                          "Data (database, files…): check before removing"),
                group: Self.volumesGroup, size: Format.parseSize(text(row, "Size")), modified: nil,
                risk: .review, preselected: false,
                removal: .tool("docker", ["volume", "rm", name], order: 2),
                symbol: "externaldrive.fill"))
        }

        // Ordre des sections conservé (cache, conteneurs, images, volumes) ; les plus lourds d'abord dans chacune.
        let order = [Self.cacheGroup, Self.containersGroup, Self.imagesGroup, Self.volumesGroup]
        return items.sorted {
            let left = order.firstIndex(of: $0.group) ?? 0, right = order.firstIndex(of: $1.group) ?? 0
            return left != right ? left < right : $0.size > $1.size
        }
    }

    // MARK: - Kubernetes

    private func clusterItems() async -> [CleanupItem] {
        var items: [CleanupItem] = []

        if let output = await ExternalTool.run("minikube", ["profile", "list", "-o", "json"], timeout: 30), output.succeeded,
           let json = try? JSONSerialization.jsonObject(with: Data(output.stdout.utf8)) as? [String: Any] {
            let profiles = (json["valid"] as? [[String: Any]] ?? []) + (json["invalid"] as? [[String: Any]] ?? [])
            for profile in profiles {
                guard let name = profile["Name"] as? String else { continue }
                items.append(cluster(name: name, tool: "minikube", arguments: ["delete", "--profile", name],
                                     size: FileScanning.allocatedSize(of: Paths.inHome(".minikube", "machines", name))))
            }
        }

        if let output = await ExternalTool.run("kind", ["get", "clusters"], timeout: 30), output.succeeded {
            for name in output.stdout.split(separator: "\n").map(String.init) where !name.isEmpty {
                items.append(cluster(name: name, tool: "kind", arguments: ["delete", "cluster", "--name", name], size: 0))
            }
        }

        if let output = await ExternalTool.run("k3d", ["cluster", "list", "-o", "json"], timeout: 30), output.succeeded,
           let clusters = try? JSONSerialization.jsonObject(with: Data(output.stdout.utf8)) as? [[String: Any]] {
            for case let name as String in clusters.map({ $0["name"] as Any }) {
                items.append(cluster(name: name, tool: "k3d", arguments: ["cluster", "delete", name], size: 0))
            }
        }
        return items
    }

    private func cluster(name: String, tool: String, arguments: [String], size: Int64) -> CleanupItem {
        CleanupItem(
            url: URL(string: "\(tool)://cluster/\(name)")!,
            name: "\(name) (\(tool))",
            detail: size > 0
                ? L("Cluster local complet : nœuds, images et données", "Whole local cluster: nodes, images and data")
                : L("Taille comprise dans les conteneurs Docker", "Size included in the Docker containers"),
            group: Self.clustersGroup, size: size, modified: nil, risk: .review, preselected: false,
            removal: .tool(tool, arguments), symbol: "network")
    }
}
