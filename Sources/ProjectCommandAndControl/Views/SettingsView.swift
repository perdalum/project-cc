import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section("Storage") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(settings.persistentStorageURL.path)
                        .textSelection(.enabled)

                    HStack {
                        Button("Choose…", action: choosePersistentStorageFile)
                        if !settings.usesDefaultPersistentStorage {
                            Button("Use Default") { settings.useDefaultPersistentStorage() }
                        }
                    }

                    Text("Default: \(AppSettings.defaultPersistentStorageURL.path)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 640)
    }

    private func choosePersistentStorageFile() {
        let panel = NSSavePanel()
        panel.title = "Choose Persistent Storage File"
        panel.message = "Select the JSON file used for persistent storage."
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = settings.persistentStorageURL.lastPathComponent
        panel.directoryURL = settings.persistentStorageURL.deletingLastPathComponent()

        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.setPersistentStorageURL(url)
    }
}
