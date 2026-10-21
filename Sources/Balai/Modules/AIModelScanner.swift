import Foundation

/// Modèles d'IA téléchargés en local. Ils se retéléchargent, mais lentement (souvent plusieurs Go) :
/// rien n'est pré-coché.
struct AIModelScanner: Scanner {
    private var redownload: String {
        L("À retélécharger si vous en avez de nouveau besoin", "Downloaded again if you need it later")
    }

    private var sources: [FolderSource] {
        [
            FolderSource(root: Paths.inHome(".lmstudio", "models"), group: "LM Studio", depth: 2, detail: redownload,
                         name: { "\($0.deletingLastPathComponent().lastPathComponent)/\($0.lastPathComponent)" }),
            FolderSource(root: Paths.inHome(".cache", "lm-studio", "models"), group: "LM Studio", depth: 2, detail: redownload,
                         name: { "\($0.deletingLastPathComponent().lastPathComponent)/\($0.lastPathComponent)" }),
            // Cache Hugging Face (transformers, diffusers, MLX…) : « models--org--nom ».
            FolderSource(root: Paths.inHome(".cache", "huggingface", "hub"), group: "Hugging Face", detail: redownload,
                         name: { Self.huggingFaceName($0) }),
            FolderSource(root: Paths.lib("Application Support", "nomic.ai", "GPT4All"), group: "GPT4All",
                         extensions: ["gguf", "bin"], detail: redownload),
            FolderSource(root: Paths.inHome("jan", "models"), group: "Jan", detail: redownload),
            FolderSource(root: Paths.lib("Application Support", "Jan", "data", "models"), group: "Jan", detail: redownload),
            FolderSource(root: Paths.inHome(".cache", "whisper"), group: "Whisper", detail: redownload),
            FolderSource(root: Paths.inHome(".cache", "torch", "hub", "checkpoints"), group: "PyTorch", detail: redownload),
            FolderSource(root: Paths.lib("Containers", "com.liuliu.draw-things", "Data", "Documents", "Models"),
                         group: "Draw Things", detail: redownload),
        ]
    }

    func scan(progress: @escaping @Sendable (String) -> Void) async -> [CleanupItem] {
        progress(L("Recherche des modèles Ollama…", "Looking for Ollama models…"))
        var items = ollamaModels()
        for source in sources {
            if Task.isCancelled { return [] }
            progress(L("Analyse de \(source.group)…", "Scanning \(source.group)…"))
            items += source.items()
        }
        return items
    }

    /// « models--mlx-community--Llama-3-8B » → « mlx-community/Llama-3-8B ».
    private static func huggingFaceName(_ url: URL) -> String? {
        let name = url.lastPathComponent
        for (prefix, suffix) in [("models--", ""), ("datasets--", " (dataset)"), ("spaces--", " (space)")]
        where name.hasPrefix(prefix) {
            return name.dropFirst(prefix.count).replacingOccurrences(of: "--", with: "/") + suffix
        }
        return nil
    }

    /// Ollama range ses modèles en manifestes qui pointent vers des blobs partagés :
    /// on lit les manifestes pour la taille, et la suppression passe par `ollama rm`.
    private func ollamaModels() -> [CleanupItem] {
        let manifests = Paths.inHome(".ollama", "models", "manifests")
        guard let enumerator = FileManager.default.enumerator(
            at: manifests, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]
        ) else { return [] }

        var items: [CleanupItem] = []
        for case let file as URL in enumerator {
            // …/manifests/<registre>/<espace>/<modèle>/<étiquette>
            let parts = Array(file.pathComponents.suffix(4))
            guard parts.count == 4,
                  (try? file.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true,
                  let data = try? Data(contentsOf: file),
                  let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            let (registry, namespace, model, tag) = (parts[0], parts[1], parts[2], parts[3])
            var name = namespace == "library" ? "\(model):\(tag)" : "\(namespace)/\(model):\(tag)"
            if registry != "registry.ollama.ai" { name = "\(registry)/\(name)" }

            let layers = (manifest["layers"] as? [[String: Any]] ?? []) + [manifest["config"] as? [String: Any] ?? [:]]
            let size = layers.reduce(Int64(0)) { $0 + (($1["size"] as? NSNumber)?.int64Value ?? 0) }
            guard size > 0 else { continue }

            items.append(CleanupItem(
                url: file, name: name,
                detail: L("Ollama · à retélécharger avec ollama pull", "Ollama · download again with ollama pull"),
                group: "Ollama", size: size, modified: FileScanning.modificationDate(of: file),
                risk: .review, preselected: false,
                removal: .tool("ollama", ["rm", name]), symbol: "brain"))
        }
        return items.sorted { $0.size > $1.size }
    }
}
