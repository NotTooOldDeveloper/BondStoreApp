import SwiftUI
import SwiftData

@MainActor
class DataCoordinator: ObservableObject {
    @Published var modelContainer: ModelContainer

    private let userDefaultsKey = "lastActiveDatabaseName"
    private var storesDirectory: URL

    var storeURL: URL? {
        modelContainer.configurations.first?.url
    }

    init() {
        do {
            // Define a dedicated directory for all database stores
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.storesDirectory = appSupportURL.appendingPathComponent("Stores")
            try FileManager.default.createDirectory(at: storesDirectory, withIntermediateDirectories: true)

            // Load the last active database or create a default one
            let lastActiveDBName = UserDefaults.standard.string(forKey: userDefaultsKey) ?? "default"
            let storeURL = storesDirectory.appendingPathComponent("\(lastActiveDBName).store")

            let config = ModelConfiguration(url: storeURL)
            self.modelContainer = try ModelContainer(for: MonthlyData.self, Seafarer.self, InventoryItem.self, Distribution.self, SupplyRecord.self, configurations: config)

        } catch {
            fatalError("Failed to create the ModelContainer: \(error)")
        }
    }

    func getAvailableDatabases() -> [String] {
        do {
            let items = try FileManager.default.contentsOfDirectory(atPath: storesDirectory.path)
            return items.filter { $0.hasSuffix(".store") }.map { $0.replacingOccurrences(of: ".store", with: "") }
        } catch {
            return ["default"]
        }
    }

    func switchDatabase(to name: String) {
        do {
            let storeURL = storesDirectory.appendingPathComponent("\(name).store")
            let config = ModelConfiguration(url: storeURL)
            let newContainer = try ModelContainer(for: MonthlyData.self, Seafarer.self, InventoryItem.self, Distribution.self, SupplyRecord.self, configurations: config)

            self.modelContainer = newContainer
            UserDefaults.standard.set(name, forKey: userDefaultsKey)
            print("✅ Switched to database: \(name)")
        } catch {
            print("❌ Failed to switch to database \(name): \(error)")
        }
    }

    func restore(from backupURL: URL, toDatabaseName name: String) throws {
        let isAccessing = backupURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                backupURL.stopAccessingSecurityScopedResource()
            }
        }

        let storeURL = storesDirectory.appendingPathComponent("\(name).store")
        let fileManager = FileManager.default

        try? fileManager.removeItem(at: storeURL)
        try? fileManager.removeItem(at: storeURL.appendingPathExtension("-shm"))
        try? fileManager.removeItem(at: storeURL.appendingPathExtension("-wal"))

        try fileManager.copyItem(at: backupURL, to: storeURL)

        // Switch to the newly restored database
        switchDatabase(to: name)
    }
    func deleteDatabase(name: String) throws {
        // Safety Check: Do not allow deleting the currently active database.
        let activeDBName = modelContainer.configurations.first?.url.deletingPathExtension().lastPathComponent
        guard name != activeDBName else {
            print("❌ Error: Cannot delete the currently active database.")
            throw NSError(domain: "DataCoordinator", code: 100, userInfo: [NSLocalizedDescriptionKey: "You cannot delete the database that is currently in use."])
        }

        let storeURL = storesDirectory.appendingPathComponent("\(name).store")
        let fileManager = FileManager.default

        try? fileManager.removeItem(at: storeURL)
        try? fileManager.removeItem(at: storeURL.appendingPathExtension("-shm"))
        try? fileManager.removeItem(at: storeURL.appendingPathExtension("-wal"))

        print("🗑️ Deleted database: \(name)")
    }

    func renameDatabase(from oldName: String, to newName: String) throws {
        // Safety Checks
        let sanitizedNewName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedNewName.isEmpty else {
            throw NSError(domain: "DataCoordinator", code: 101, userInfo: [NSLocalizedDescriptionKey: "New database name cannot be empty."])
        }
        guard !getAvailableDatabases().contains(sanitizedNewName) else {
            throw NSError(domain: "DataCoordinator", code: 102, userInfo: [NSLocalizedDescriptionKey: "A database with this name already exists."])
        }

        let oldURL = storesDirectory.appendingPathComponent("\(oldName).store")
        let newURL = storesDirectory.appendingPathComponent("\(sanitizedNewName).store")

        try FileManager.default.moveItem(at: oldURL, to: newURL)

        // If we renamed the active database, we must switch to it to update the container path
        let activeDBName = modelContainer.configurations.first?.url.deletingPathExtension().lastPathComponent
        if oldName == activeDBName {
            switchDatabase(to: sanitizedNewName)
        }

        print("✏️ Renamed database from '\(oldName)' to '\(sanitizedNewName)'")
    }
    
}
