import Foundation

/// Machines virtuelles et émulateurs : de très gros fichiers qui contiennent souvent des données.
/// Tout est « à vérifier » et rien n'est pré-coché.
struct VirtualMachineScanner: Scanner {
    private var stopFirst: String {
        L("Arrêtez la machine avant de la supprimer", "Shut the machine down before removing it")
    }

    private var sources: [FolderSource] {
        let notHidden: @Sendable (URL) -> String? = { $0.lastPathComponent.hasPrefix("_") ? nil : $0.lastPathComponent }
        return [
            FolderSource(root: Paths.lib("Containers", "com.utmapp.UTM", "Data", "Documents"), group: "UTM",
                         extensions: ["utm"], detail: stopFirst),
            FolderSource(root: Paths.inHome("Parallels"), group: "Parallels", extensions: ["pvm"], detail: stopFirst),
            FolderSource(root: Paths.inHome("Documents", "Parallels"), group: "Parallels", extensions: ["pvm"], detail: stopFirst),
            FolderSource(root: Paths.inHome("Virtual Machines.localized"), group: "VMware Fusion",
                         extensions: ["vmwarevm"], detail: stopFirst),
            FolderSource(root: Paths.inHome("VirtualBox VMs"), group: "VirtualBox", detail: stopFirst),
            FolderSource(root: Paths.inHome(".android", "avd"), group: L("Émulateurs Android", "Android Emulators"),
                         extensions: ["avd"], detail: stopFirst),
            FolderSource(root: Paths.lib("Android", "sdk", "system-images"),
                         group: L("Images système Android", "Android System Images"),
                         detail: L("Retéléchargeables depuis Android Studio", "Downloadable again from Android Studio")),
            FolderSource(root: Paths.inHome(".vagrant.d", "boxes"), group: "Vagrant",
                         detail: L("Boîte de base, retéléchargée par vagrant up", "Base box, downloaded again by vagrant up")),
            FolderSource(root: Paths.inHome(".lima"), group: "Lima", detail: stopFirst, name: notHidden),
            FolderSource(root: Paths.inHome(".colima", "_lima"), group: "Colima",
                         detail: L("Arrêtez-la d'abord (colima stop)", "Stop it first (colima stop)"), name: notHidden),
            FolderSource(root: Paths.inHome(".local", "share", "containers", "podman", "machine"), group: "Podman",
                         detail: L("Arrêtez-la d'abord (podman machine stop)", "Stop it first (podman machine stop)")),
            FolderSource(root: Paths.inHome(".tart", "vms"), group: "Tart", detail: stopFirst),
        ]
    }

    func scan(progress: @escaping @Sendable (String) -> Void) async -> [CleanupItem] {
        var items: [CleanupItem] = []
        for source in sources {
            if Task.isCancelled { return [] }
            progress(L("Analyse de \(source.group)…", "Scanning \(source.group)…"))
            items += source.items()
        }
        return items
    }
}
