import SwiftUI
import SwiftData

struct SettingsView: View {
    // The state properties at the top of the view
    @EnvironmentObject var dataCoordinator: DataCoordinator
    @Environment(\.modelContext) private var modelContext

    // State for the file exporter
    @State private var documentToExport: DatabaseFile?
    @State private var isExporting = false // Add this state variable back

    // State for the file importer
    @State private var isImporting = false

    // State for the restore confirmation alert
    @State private var showRestoreAlert = false
    @State private var importedURL: URL?

    var body: some View {
        NavigationView {
            Form {
                Section("Data Management") {
                    NavigationLink("Manage & Switch Databases") {
                        DatabaseManagementView()
                    }
                    Button("Backup Active Database") {
                        backupDatabase()
                    }
                    Button("Restore from Backup", role: .destructive) {
                        isImporting = true
                    }
                }
            }
            .navigationTitle("Settings")
            // The .fileExporter modifier
            .fileExporter(isPresented: $isExporting, document: documentToExport, contentType: .database, defaultFilename: "BondStoreBackup.store") { result in
                switch result {
                case .success(let url):
                    print("Backup saved to: \(url)")
                case .failure(let error):
                    print("Backup failed: \(error.localizedDescription)")
                }
                // Reset the document after the operation is complete
                documentToExport = nil
            }
            .onChange(of: documentToExport) {
                // When a new document is prepared, set the isExporting flag to true.
                // This safely separates preparing the file from presenting the sheet.
                if documentToExport != nil {
                    isExporting = true
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.database]) { result in
                switch result {
                case .success(let url):
                    self.importedURL = url
                    self.showRestoreAlert = true
                case .failure(let error):
                    print("Import failed: \(error.localizedDescription)")
                }
            }
            .alert("Restore Backup?", isPresented: $showRestoreAlert, presenting: importedURL) { url in
                Button("Restore", role: .destructive) {
                    restoreDatabase(from: url)
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("This will create a new database from the backup file and switch to it. Your current data will not be overwritten unless it has the same name.")
            }
        }
    }

    private func backupDatabase() {
        guard let storeURL = dataCoordinator.storeURL else {
            print("Could not find database store URL from coordinator.")
            return
        }

        do {
            let data = try Data(contentsOf: storeURL)
            // This function now ONLY prepares the document.
            // The .onChange modifier will handle showing the sheet.
            self.documentToExport = DatabaseFile(data: data)
        } catch {
            print("Failed to read database file for backup: \(error)")
        }
    }


    private func restoreDatabase(from backupURL: URL) {
        let backupName = backupURL.deletingPathExtension().lastPathComponent
        let restoreName = backupName.isEmpty ? "RestoredDatabase" : backupName

        do {
            try dataCoordinator.restore(from: backupURL, toDatabaseName: restoreName)
        } catch {
            print("❌ Failed to perform live restore: \(error)")
        }
    }
}
