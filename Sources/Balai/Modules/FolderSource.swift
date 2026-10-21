import Foundation

/// Un dossier connu dont chaque élément est proposé séparément : un modèle d'IA, une machine virtuelle…
struct FolderSource: Sendable {
    let root: URL
    let group: String
    /// 1 : les éléments du dossier ; 2 : un niveau plus bas (« éditeur/modèle »).
    var depth = 1
    /// Extensions retenues (minuscules) ; vide = tout.
    var extensions: Set<String> = []
    var detail: String?
    var risk: Risk = .review
    var preselected = false
    var symbol: String?
    /// Nom affiché à partir de l'URL ; `nil` pour ignorer l'élément.
    var name: @Sendable (URL) -> String? = { $0.lastPathComponent }

    func items() -> [CleanupItem] {
        var urls = FileScanning.children(of: root)
        if depth == 2 {
            urls = urls.filter(FileScanning.isDirectory).flatMap(FileScanning.children(of:))
        }
        return urls.compactMap { url -> CleanupItem? in
            guard !url.lastPathComponent.hasPrefix("."),
                  extensions.isEmpty || extensions.contains(url.pathExtension.lowercased()),
                  let displayName = name(url),
                  var item = FileScanning.makeItem(
                      url: url, name: displayName,
                      detail: detail ?? Format.abbreviate(url.deletingLastPathComponent()),
                      group: group, risk: risk, preselected: preselected)
            else { return nil }
            item.symbol = symbol
            return item
        }
        .sorted { $0.size > $1.size }
    }
}
