import SwiftUI
import SwiftData
import UniformTypeIdentifiers // ✅ Needed for .csv file type
import Foundation // Needed for SortDescriptor if not implicitly picked up by SwiftData, also for basic String operations

struct SeafarersListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    var month: MonthlyData // Ensure MonthlyData is an @Model and seafarers is a @Relationship

    @State private var showingAddSeafarer = false
    @State private var newID = ""
    @State private var newName = ""
    @State private var newRank = ""
    @State private var newIsRepresentative = false

    @State private var showingFileImporter = false
    // Using a single state for import feedback and alert presentation
    @State private var importFeedbackMessage: String?
    @State private var showingImportAlert = false
    private var monthDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.date(from: month.monthID) ?? Date()
    }

    var body: some View {
        NavigationView {
            List {
                // Ensure `SortDescriptor` is working.
                // If this line causes an error, try `sorted(by: { $0.displayID < $1.displayID })`
                ForEach(month.seafarers.sorted(using: SortDescriptor(\.displayID)), id: \.id) { seafarer in
                    VStack(alignment: .leading) {
                        NavigationLink(destination: SeafarerDetailView(seafarer: seafarer, inventoryItems: month.inventoryItems)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("\(seafarer.displayID).")
                                            .bold()
                                        Text(seafarer.name)
                                            .bold()
                                    }
                                    Text(seafarer.rank)
                                        .font(.subheadline)
                                }
                                Spacer()
                                Text("Spent: €\(seafarer.totalSpent, specifier: "%.2f")") // Changed $ to €
                                    .font(.headline)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteSeafarers)
            }
            .navigationTitle("Seafarers – \(formattedMonthName(from: monthDate))")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Add Seafarer") {
                            showingAddSeafarer = true
                        }
                        Button("Import CSV") {
                            showingFileImporter = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .imageScale(.large)
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                // Using .commaSeparatedText which covers .csv. You can also add .text for more flexibility.
                allowedContentTypes: [.commaSeparatedText, .text],
                allowsMultipleSelection: false
            ) { result in
                handleFileImportResult(result) // Call the new handler function
            }
            .sheet(isPresented: $showingAddSeafarer) {
                NavigationView {
                    Form {
                        TextField("ID", text: $newID)
                        TextField("Name", text: $newName)
                        TextField("Rank", text: $newRank)
                        Toggle("Is Representative", isOn: $newIsRepresentative)
                    }
                    .navigationTitle("New Seafarer")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                addNewSeafarer() // Renamed for clarity
                            }
                            .disabled(newID.isEmpty || newName.isEmpty || newRank.isEmpty)
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingAddSeafarer = false
                                resetNewSeafarerFields()
                            }
                        }
                    }
                }
            }
            // Alert to show import results or errors
            .alert("Import Status", isPresented: $showingImportAlert, presenting: importFeedbackMessage) { message in
                Button("OK") { importFeedbackMessage = nil }
            } message: { message in
                Text(message)
            }
        }
    }

    // MARK: - Seafarer Management Actions
    private func addNewSeafarer() {
        let seafarer = Seafarer(
            displayID: newID.trimmingCharacters(in: .whitespacesAndNewlines),
            name: newName.trimmingCharacters(in: .whitespacesAndNewlines),
            rank: newRank.trimmingCharacters(in: .whitespacesAndNewlines),
            isRepresentative: newIsRepresentative
        )

        if month.seafarers.contains(where: { $0.displayID == seafarer.displayID }) {
            importFeedbackMessage = "A seafarer with ID '\(seafarer.displayID)' already exists. Please use a unique ID."
            showingImportAlert = true
            return
        }

        month.seafarers.append(seafarer)
        modelContext.insert(seafarer)
        
        do {
            try modelContext.save() // Explicitly save after adding
            print("🟢 Successfully added new seafarer and saved context.")
        } catch {
            print("🔴 Failed to save context after adding seafarer: \(error.localizedDescription)")
            importFeedbackMessage = "Failed to save new seafarer: \(error.localizedDescription)"
            showingImportAlert = true
        }

        showingAddSeafarer = false
        resetNewSeafarerFields()
    }

    private func deleteSeafarers(at offsets: IndexSet) {
        let sortedSeafarers = month.seafarers.sorted(using: SortDescriptor(\.displayID))
        for index in offsets {
            let seafarerToDelete = sortedSeafarers[index]
            month.seafarers.removeAll { $0.id == seafarerToDelete.id }
            modelContext.delete(seafarerToDelete)
        }
        
        do {
            try modelContext.save() // Explicitly save after deletion
            print("🟢 Successfully deleted seafarers and saved context.")
        } catch {
            print("🔴 Failed to save context after deleting seafarers: \(error.localizedDescription)")
        }
    }
    
    private func resetNewSeafarerFields() {
        newID = ""
        newName = ""
        newRank = ""
        newIsRepresentative = false
    }

    // MARK: - CSV Import Logic Handlers
    private func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else {
                importFeedbackMessage = "No file was selected for import."
                showingImportAlert = true
                return
            }
            importSeafarers(from: fileURL)
        case .failure(let error):
            importFeedbackMessage = "File import cancelled or failed: \(error.localizedDescription)"
            showingImportAlert = true
            print("❌ File import failed: \(error.localizedDescription)")
        }
    }

    private func importSeafarers(from url: URL) {
        // !!! CRITICAL: Accessing Security-Scoped Resources !!!
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        var importedCount = 0
        var skippedCount = 0
        var errorRows: [Int] = []

        do {
            let csvString = try String(contentsOf: url, encoding: .utf8)
            let lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }

            // Iterate through lines, assuming no header line for simplicity as your original example didn't explicitly use dropFirst()
            // If your CSV *does* have a header, uncomment .dropFirst()
            for (index, line) in lines.enumerated() { //.dropFirst() if you have a header row
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                let components: [String]
                // Re-added robust delimiter check (pipe or comma)
                if trimmedLine.contains("|") {
                    components = trimmedLine.components(separatedBy: "|")
                } else {
                    components = trimmedLine.components(separatedBy: ",")
                }

                guard components.count == 3 else {
                    print("Skipping row \(index + 1) ('\(line)') due to incorrect number of components (\(components.count) instead of 3).")
                    errorRows.append(index + 1)
                    skippedCount += 1
                    continue
                }

                let displayID = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let name = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let rank = components[2].trimmingCharacters(in: .whitespacesAndNewlines)

                guard !displayID.isEmpty, !name.isEmpty, !rank.isEmpty else {
                    print("Skipping row \(index + 1) ('\(line)') due to empty fields.")
                    errorRows.append(index + 1)
                    skippedCount += 1
                    continue
                }
                
                // Check for duplicate ID
                if month.seafarers.contains(where: { $0.displayID == displayID }) {
                    print("Skipping row \(index + 1): Seafarer with ID '\(displayID)' already exists.")
                    errorRows.append(index + 1)
                    skippedCount += 1
                    continue
                }

                let newSeafarer = Seafarer(displayID: displayID, name: name, rank: rank)
                month.seafarers.append(newSeafarer)
                modelContext.insert(newSeafarer)
                importedCount += 1
            }

            // After processing all lines, save the context
            if importedCount > 0 {
                try modelContext.save()
                importFeedbackMessage = "Successfully imported \(importedCount) seafarer(s)."
                print("🟢 Model context saved after CSV import.")
            } else if skippedCount > 0 {
                importFeedbackMessage = "No new seafarers were imported. \(skippedCount) row(s) were skipped due to errors or duplicates."
                if !errorRows.isEmpty {
                    importFeedbackMessage! += " Issues in rows: \(errorRows.map(String.init).joined(separator: ", "))."
                }
            } else {
                importFeedbackMessage = "No seafarers found in the CSV file or all rows were skipped."
            }
            showingImportAlert = true

        } catch {
            importFeedbackMessage = "Failed to read or parse CSV file: \(error.localizedDescription)"
            showingImportAlert = true
            print("🔴 CSV import process failed: \(error.localizedDescription)")
        }
    }
}

    private func formattedMonthName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        return formatter.string(from: date)
    }
