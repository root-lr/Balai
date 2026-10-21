import SwiftUI

struct SettingsView: View {
    @AppStorage(Defaults.deletionMode) private var deletionMode: DeletionMode = .trash
    @AppStorage(Defaults.largeFileThresholdMB) private var thresholdMB = 500
    @AppStorage(Defaults.staleProjectDays) private var staleDays = 30
    @AppStorage(Defaults.language) private var language = AppLanguage.system.rawValue

    /// La langue est appliquée avant que l'interface ne se redessine.
    private var languageSelection: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: language) ?? .system },
            set: { newValue in
                UserDefaults.standard.set(newValue.rawValue, forKey: Defaults.language)
                AppLanguage.refresh()
                language = newValue.rawValue
            }
        )
    }

    var body: some View {
        Form {
            Section(L("Général", "General")) {
                Picker(L("Langue", "Language"), selection: languageSelection) {
                    ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
                }
            }

            Section(L("Suppression", "Deletion")) {
                Picker(L("Mode proposé par défaut", "Default mode"), selection: $deletionMode) {
                    ForEach(DeletionMode.allCases) { Text($0.label).tag($0) }
                }
                Text(L("Vous pouvez toujours changer de mode au moment de confirmer.",
                       "You can always change the mode when confirming."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L("Analyse", "Scanning")) {
                Picker(L("Taille minimale des gros fichiers", "Minimum size for large files"), selection: $thresholdMB) {
                    ForEach([100, 250, 500, 1_000, 5_000], id: \.self) { mb in
                        Text(Format.bytes(Int64(mb) * 1_000_000)).tag(mb)
                    }
                }
                Stepper(value: $staleDays, in: 7...365, step: 7) {
                    Text(L("Pré-cocher les node_modules inactifs depuis \(staleDays) jours",
                           "Preselect node_modules idle for \(staleDays) days"))
                }
            }

            Section(L("Autorisations", "Permissions")) {
                HStack {
                    Label(
                        Permissions.hasFullDiskAccess
                            ? L("Accès complet au disque accordé", "Full Disk Access granted")
                            : L("Accès complet au disque non accordé", "Full Disk Access not granted"),
                        systemImage: Permissions.hasFullDiskAccess ? "checkmark.shield" : "exclamationmark.shield"
                    )
                    .foregroundStyle(Permissions.hasFullDiskAccess ? Color.green : Color.orange)
                    Spacer()
                    Button(L("Ouvrir les réglages", "Open Settings")) { Permissions.openFullDiskAccessSettings() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .id(language)
    }
}
