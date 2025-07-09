import SwiftUI
import SwiftData
import UniformTypeIdentifiers // ✅ Needed for .csv file type
import Foundation // Needed for SortDescriptor if not implicitly picked up by SwiftData, also for basic String operations

struct SeafarersListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    var month: MonthlyData // Ensure MonthlyData is an @Model and seafarers is a @Relationship

    @State private var showingAddSeafarer = false
    // The state variables at the top of the View
    @State private var newID = ""
    @State private var newName = ""
    @State private var newRank = ""
    @State private var newIsRepresentative = false
    @State private var newDate = Date() // New state for the DatePicker

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
                let representatives = month.seafarers.filter { $0.isRepresentative }
                let regularSeafarers = month.seafarers.filter { !$0.isRepresentative }

                // --- Representatives Section ---
                if !representatives.isEmpty {
                    Section(header: Text("Representatives")) {
                        ForEach(representatives) { seafarer in
                            NavigationLink(destination: SeafarerDetailView(seafarer: seafarer)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        // Representative's name on the top line
                                        Text("\(seafarer.rank) - \(seafarer.displayID)")
                                            .bold()
                                        // Date and Port Name on the bottom line
                                        Text(seafarer.name)
                                            .font(.subheadline)
                                    }
                                    Spacer()
                                    Text("Spent: €\(seafarer.totalSpent, specifier: "%.2f")")
                                        .font(.headline)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            // We now explicitly tell the delete function to use the 'representatives' list
                            let representatives = month.seafarers.filter { $0.isRepresentative }
                            delete(at: indexSet, from: representatives)
                        }
                    }
                }

                // --- Seafarers Section ---
                if !regularSeafarers.isEmpty {
                    Section(header: Text("Seafarers")) {
                        ForEach(regularSeafarers.sorted(using: SortDescriptor(\.displayID))) { seafarer in
                            NavigationLink(destination: SeafarerDetailView(seafarer: seafarer)) {
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
                                    Text("Spent: €\(seafarer.totalSpent, specifier: "%.2f")")
                                        .font(.headline)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            // And here we tell it to use the 'regularSeafarers' list
                            let regularSeafarers = month.seafarers.filter { !$0.isRepresentative }.sorted(using: SortDescriptor(\.displayID))
                            delete(at: indexSet, from: regularSeafarers)
                        }
                    }
                }
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
                        // --- Dynamic Fields ---
                        if newIsRepresentative {
                            // Fields for a Representative
                            DatePicker("Date", selection: $newDate, displayedComponents: .date)
                            TextField("Port Name", text: $newID)
                            TextField("Representative Name", text: $newName)
                        } else {
                            // Fields for a regular Seafarer
                            TextField("ID", text: $newID)
                            TextField("Name", text: $newName)
                            TextField("Rank", text: $newRank)
                        }

                        // --- Toggle ---
                        Toggle("Is Representative", isOn: $newIsRepresentative.animation())
                    }
                    .navigationTitle(newIsRepresentative ? "New Representative" : "New Seafarer")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                addNewSeafarer()
                            }
                            // Disable button if required fields are empty
                            .disabled(newID.isEmpty || newName.isEmpty || (!newIsRepresentative && newRank.isEmpty))
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
        let trimmedID = newID.trimmingCharacters(in: .whitespacesAndNewlines)

        if month.seafarers.contains(where: { $0.displayID == trimmedID && !$0.isRepresentative }) {
            importFeedbackMessage = "A seafarer with ID '\(trimmedID)' already exists. Please use a unique ID."
            showingImportAlert = true
            return
        }

        // Determine rank based on whether it's a representative or not
        let finalRank: String
        // Inside the addNewSeafarer() function
        if newIsRepresentative {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yy" // Sets the format to day.month.year
            finalRank = formatter.string(from: newDate)
        } else {
            finalRank = newRank.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let seafarer = Seafarer(
            displayID: trimmedID,
            name: newName.trimmingCharacters(in: .whitespacesAndNewlines),
            rank: finalRank, // Use the determined rank
            isRepresentative: newIsRepresentative
        )
        seafarer.monthlyData = month

        modelContext.insert(seafarer)

        do {
            try modelContext.save()
            print("🟢 Successfully added new entry and saved context.")
        } catch {
            print("🔴 Failed to save context: \(error.localizedDescription)")
            importFeedbackMessage = "Failed to save new entry: \(error.localizedDescription)"
            showingImportAlert = true
        }

        showingAddSeafarer = false
        resetNewSeafarerFields()
    }

    private func delete(at offsets: IndexSet, from collection: [Seafarer]) {
        // This function now correctly identifies the item from the specific collection it was given.
        for index in offsets {
            let itemToDelete = collection[index]
            modelContext.delete(itemToDelete)
        }

        // It's good practice to save once after all deletions are staged.
        do {
            try modelContext.save()
            print("🟢 Successfully deleted item(s) and saved context.")
        } catch {
            print("🔴 Failed to save context after deletion: \(error.localizedDescription)")
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
                newSeafarer.monthlyData = month // This line is crucial
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
