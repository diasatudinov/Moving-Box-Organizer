import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                if let url = viewModel.exportURL {
                    ShareLink(item: url) {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }
                }
                Button(action: viewModel.importTapped) {
                    Label("Import Data", systemImage: "square.and.arrow.down")
                }
                if viewModel.hasSnapshot {
                    Button(action: viewModel.restoreSnapshotTapped) {
                        Label("Restore Data from Before Last Import", systemImage: "clock.arrow.circlepath")
                    }
                }
            } header: {
                Text("Backup")
            } footer: {
                Text("Your data is stored only on this iPhone. Save a copy to Files before changing phones. Importing replaces all current data.")
            }

            Section("About") {
                LabeledContent("Version", value: viewModel.versionText)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: viewModel.doneTapped)
            }
        }
        .fileImporter(isPresented: $viewModel.isImporterPresented, allowedContentTypes: [.storageBackup, .json]) { result in
            switch result {
            case .success(let url): viewModel.importFileSelected(url)
            case .failure(let error): viewModel.importFailed(error)
            }
        }
        .onAppear(perform: viewModel.onAppear)
        .alert($viewModel.alert)
    }
}
