//
//  DatabaseManagementView.swift
//  BondStoreApp
//
//  Created by Valentyn on 22.07.25.
//

import SwiftUI

struct DatabaseManagementView: View {
    @EnvironmentObject var dataCoordinator: DataCoordinator
    @State private var databases: [String] = []

    // State for creating a new database
    @State private var showingCreateAlert = false
    @State private var newDatabaseName = ""

    // State for renaming a database
    @State private var showingRenameAlert = false
    @State private var itemToRename: String?
    @State private var newNameForRename = ""

    // State for showing errors
    @State private var errorAlertMessage: String?
    @State private var isShowingErrorAlert = false

    private var activeDatabase: String {
        dataCoordinator.modelContainer.configurations.first?.url.deletingPathExtension().lastPathComponent ?? "Unknown"
    }

    var body: some View {
        Form {
            Section("Available Databases") {
                ForEach(databases, id: \.self) { dbName in
                    HStack {
                        Text(dbName)
                        Spacer()
                        if dbName == activeDatabase {
                            Image(systemName: "checkmark")
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dataCoordinator.switchDatabase(to: dbName)
                    }
                    .swipeActions(edge: .leading) {
                        Button("Rename") {
                            itemToRename = dbName
                            newNameForRename = dbName
                            showingRenameAlert = true
                        }
                        .tint(.blue)
                    }
                }
                .onDelete(perform: delete)
            }

            Section {
                Button("Create New Database") {
                    newDatabaseName = ""
                    showingCreateAlert = true
                }
            }
        }
        .navigationTitle("Manage Databases")
        .onAppear(perform: loadDatabases)
        .alert("New Database", isPresented: $showingCreateAlert) {
            TextField("Database Name", text: $newDatabaseName)
            Button("Create & Switch") {
                handleCreate(name: newDatabaseName)
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename Database", isPresented: $showingRenameAlert) {
            TextField("New Name", text: $newNameForRename)
            Button("Save") {
                if let oldName = itemToRename {
                    handleRename(from: oldName, to: newNameForRename)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Error", isPresented: $isShowingErrorAlert, presenting: errorAlertMessage) { message in
            Button("OK") {}
        } message: { message in
            Text(message)
        }
    }

    private func loadDatabases() {
        databases = dataCoordinator.getAvailableDatabases().sorted()
    }

    private func delete(at offsets: IndexSet) {
        let namesToDelete = offsets.map { databases[$0] }
        for name in namesToDelete {
            do {
                try dataCoordinator.deleteDatabase(name: name)
            } catch {
                errorAlertMessage = error.localizedDescription
                isShowingErrorAlert = true
            }
        }
        loadDatabases()
    }

    private func handleCreate(name: String) {
        let sanitizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sanitizedName.isEmpty && !databases.contains(sanitizedName) {
            dataCoordinator.switchDatabase(to: sanitizedName)
            loadDatabases()
        }
    }

    private func handleRename(from oldName: String, to newName: String) {
        do {
            try dataCoordinator.renameDatabase(from: oldName, to: newName)
            loadDatabases()
        } catch {
            errorAlertMessage = error.localizedDescription
            isShowingErrorAlert = true
        }
    }
}
