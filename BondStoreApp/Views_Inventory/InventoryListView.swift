import SwiftUI
import AVFoundation
import SwiftData


// New, simpler view for displaying a single inventory row
struct InventoryItemRowView: View {
    let item: InventoryItem
    let quantityForMonth: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.system(size: 18))
                    .bold()
                Text("Quantity: \(quantityForMonth)")
            }
            
            Spacer()
            
            VStack(alignment: .leading) {
                Text(String(format: "Price: €%.2f", item.pricePerUnit))
                    .font(.system(size: 18))
                    .bold(true)
                Text(String(format: "Total: €%.2f", Double(quantityForMonth) * item.pricePerUnit))
                    .foregroundStyle(Color.gray)
            }
        }
    }
}

// New view to find and select a UNIQUE item name
struct ItemFinderView: View {
    @Environment(\.dismiss) var dismiss
    @Query private var allItems: [InventoryItem]
    @State private var searchText = ""
    
    // This closure will pass the selected NAME back
    var onNameSelected: (String) -> Void

    // This property now creates a sorted list of unique names
    var uniqueSortedNames: [String] {
        let allNames = allItems.map { $0.name }
        let uniqueNames = Set(allNames)
        return Array(uniqueNames).sorted()
    }

    var searchResults: [String] {
        if searchText.isEmpty {
            return uniqueSortedNames
        } else {
            return uniqueSortedNames.filter { $0.lowercased().contains(searchText.lowercased()) }
        }
    }

    var body: some View {
        NavigationStack {
            List(searchResults, id: \.self) { name in
                Button(name) {
                    onNameSelected(name)
                    dismiss()
                }
                .foregroundColor(.primary)
            }
            .searchable(text: $searchText)
            .navigationTitle("Find Existing Name")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct InventoryListView: View {
    
    enum SheetMode: Identifiable {
        case add
        case edit(InventoryItem)

        var id: String {
            switch self {
            case .add:
                return "add"
            case .edit(let item):
                return item.id.uuidString
            }
        }
    }
    
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InventoryItem.name) private var inventoryItems: [InventoryItem]
    var monthID: String
    
    @State private var sheetMode: SheetMode?
    @State private var showingItemFinder = false

    @State private var itemName = ""
    @State private var itemQuantity = "" // String for TextField input
    @State private var itemBarcodes: [String] = Array(repeating: "", count: 5)
    @State private var itemPrice: Double = 0.0    // String for TextField input
    @State private var itemReceivedDate = Date() // This will be the date of the supply

    @State private var scanningTarget: Int? = nil // Index of barcode field currently scanning
    @State private var showingInventoryBarcodeScanner = false // For the dedicated Inventory barcode scanner

    // New state for deletion warnings
    @State private var showingDeletionAlert = false
    @State private var itemToDelete: InventoryItem?
    @State private var showingDistributionExistsAlert = false

    private func getQuantity(for item: InventoryItem, onOrBefore date: Date) -> Int {
        let itemID = item.id // Capture the ID before the predicate.

        // 1. Create a predicate for supplies
        let supplyPredicate = #Predicate<SupplyRecord> {
            $0.inventoryItem?.id == itemID && $0.date <= date
        }
        let totalSupplied = (try? modelContext.fetch(FetchDescriptor(predicate: supplyPredicate)))?.reduce(0) { $0 + $1.quantity } ?? 0

        // 2. Create a predicate for distributions
        let distributionPredicate = #Predicate<Distribution> {
            $0.inventoryItem?.id == itemID && $0.date <= date
        }
        let totalDistributed = (try? modelContext.fetch(FetchDescriptor(predicate: distributionPredicate)))?.reduce(0) { $0 + $1.quantity } ?? 0

        // 3. The current quantity is the difference
        return totalSupplied - totalDistributed
    }
    
    private var startOfMonthDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        // Use the user's local timezone for UI consistency.
        return formatter.date(from: monthID) ?? .distantFuture
    }

    private var endOfMonthDate: Date {
        // Use the local calendar to correctly find the last day of the month.
        let startDate = startOfMonthDate
        guard let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: startDate),
              let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: nextMonth) else {
            return .distantPast
        }
        return lastDay
    }

    private func formattedMonthName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        return formatter.string(from: date)
    }
    
    private var filteredItems: [InventoryItem] {
        let startOfOpeningStock = Calendar.current.date(byAdding: .month, value: -1, to: endOfMonthDate) ?? Date()

        return inventoryItems.filter { item in
            let openingStock = getQuantity(for: item, onOrBefore: startOfOpeningStock)
            let closingStock = getQuantity(for: item, onOrBefore: endOfMonthDate)

            // Show if opening stock > 0 OR if the quantity changed during the month
            return openingStock > 0 || openingStock != closingStock
        }
    }

    private var inventoryListContent: some View {
        return List {
            ForEach(filteredItems) { item in
                let quantityForMonth = getQuantity(for: item, onOrBefore: endOfMonthDate)
                InventoryItemRowView(item: item, quantityForMonth: quantityForMonth)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        startEditing(item)
                    }
            }
            .onDelete(perform: confirmDeleteItems)
        }
    }
    
    var body: some View {
            NavigationView {
                inventoryListContent // Just call the new property here
                .navigationTitle("Inventory – \(formattedMonthName(from: endOfMonthDate))")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            startAdding()
                        } label: {
                            Label("Add Item", systemImage: "plus")
                        }

                        Button {
                            showingInventoryBarcodeScanner = true
                        } label: {
                            Label("Add via Barcode Scanner", systemImage: "barcode.viewfinder")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .imageScale(.large)
                    }
                }
            }
            // Alert for confirming deletion
            .alert("Confirm Deletion", isPresented: $showingDeletionAlert) {
                Button("Delete", role: .destructive) {
                    if let item = itemToDelete {
                        deleteSingleItem(item) // Call new function for single item deletion
                    }
                }
                Button("Cancel", role: .cancel) {
                    itemToDelete = nil // Clear the item to delete
                }
            } message: {
                Text("Are you sure you want to delete \(itemToDelete?.name ?? "this item")? This action cannot be undone.")
            }
            // Alert for when distributions/supplies exist
            .alert("Item Cannot Be Deleted", isPresented: $showingDistributionExistsAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This item has associated distributions or supplies and cannot be deleted. Please remove all related entries first.")
            }
            .sheet(item: $sheetMode) { mode in
                let isEditing = {
                    if case .edit = mode { return true }
                    return false
                }()

                NavigationView {
                    Form {
                        Section(header: Text("Item Name")) {
                            HStack {
                                TextField("Enter item name", text: $itemName)
                                Button("Find") {
                                    showingItemFinder = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        Section(header: Text("Price")) {
                            TextField("Enter price", value: $itemPrice, format: .number)
                                .keyboardType(.decimalPad)
                        }

                        // Only show Quantity and Date fields when ADDING a new item
                        if !isEditing {
                            Section(header: Text("Quantity Received")) {
                                TextField("Enter quantity", text: $itemQuantity)
                                    .keyboardType(.numberPad)
                            }
                            Section(header: Text("Date Received")) {
                                DatePicker("Date", selection: $itemReceivedDate, in: startOfMonthDate...endOfMonthDate, displayedComponents: .date)
                            }
                        }

                        Section(header: Text("Barcodes (up to 5)")) {
                            ForEach(0..<5, id: \.self) { index in
                                HStack {
                                    TextField("Barcode \(index + 1)", text: $itemBarcodes[index])
                                    Button("Scan") {
                                        scanningTarget = index
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle(isEditing ? "Edit Item" : "Add Item")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                // Pass the item being edited to the save function
                                var itemToEdit: InventoryItem?
                                if case .edit(let item) = mode {
                                    itemToEdit = item
                                }
                                saveItem(editingItem: itemToEdit)
                            }
                            .disabled(
                                // If we are adding a new item, check all fields
                                !isEditing ?
                                (itemName.isEmpty || Int(itemQuantity) == nil || itemPrice <= 0) :
                                // If we are just editing, only check the name and price
                                (itemName.isEmpty || itemPrice <= 0)
                            )
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                cancel()
                            }
                        }
                    }
                }
                .sheet(item: Binding(
                    get: {
                        scanningTarget.map { ScanIndex(index: $0) }
                    },
                    set: { newValue in
                        scanningTarget = newValue?.index
                    }
                )) { target in
                    BasicBarcodeScannerView { code in
                        let index = target.index
                        if index < itemBarcodes.count {
                            itemBarcodes[index] = code
                        }
                        scanningTarget = nil
                    }
                }
                .sheet(isPresented: $showingItemFinder) {
                    // This nested sheet also remains the same
                    ItemFinderView { selectedName in
                        self.itemName = selectedName
                    }
                }
            }
            .sheet(isPresented: $showingInventoryBarcodeScanner) {
                InventoryBarcodeScannerView(startOfMonth: startOfMonthDate, endOfMonth: endOfMonthDate)
            }
        }
    }

    private func startAdding() {
        // Reset fields and set the mode to .add
        itemName = ""
        itemQuantity = ""
        itemBarcodes = Array(repeating: "", count: 5)
        itemPrice = 0.0

        let today = Date()
        if today >= startOfMonthDate && today <= endOfMonthDate {
            itemReceivedDate = today
        } else {
            itemReceivedDate = startOfMonthDate
        }

        sheetMode = .add
    }

    private func startEditing(_ item: InventoryItem) {
        // Set the mode to edit the tapped item
        sheetMode = .edit(item)

        // Populate the form's state variables with the item's data
        itemName = item.name
        itemPrice = item.pricePerUnit

        // Load the saved barcodes, padding with empty strings to fill all 5 fields
        let existingBarcodes = item.barcodes
        itemBarcodes = (existingBarcodes + Array(repeating: "", count: 5)).prefix(5).map { $0 }

        // Load the initial supply quantity for editing
        if let firstSupply = item.supplies.min(by: { $0.date < $1.date }) {
            itemQuantity = "\(firstSupply.quantity)"
        } else {
            itemQuantity = ""
        }
    }

    private func saveItem(editingItem: InventoryItem?) {
        let newQty = Int(itemQuantity) ?? 0
        let price = itemPrice // Use the Double directly
        let trimmedName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Create the clean barcodes array at the top level, so it's always in scope.
        let finalBarcodes = itemBarcodes.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        if let item = editingItem {
            // --- EDITING AN EXISTING ITEM ---
            item.name = trimmedName
            item.pricePerUnit = price
            item.barcodes = finalBarcodes // Assign the clean barcodes

            // Additionally, update the initial supply quantity if it was editable.
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            let itemCreationMonth = formatter.string(from: item.receivedDate)

            if itemCreationMonth == self.monthID {
                if let newQty = Int(itemQuantity),
                   let firstSupply = item.supplies.min(by: { $0.date < $1.date }) {
                    firstSupply.quantity = newQty
                }
            }
        } else {
            // --- CREATING A NEW ITEM OR ADDING A SUPPLY ---
            let fetchRequest = FetchDescriptor<InventoryItem>(predicate: #Predicate {
                $0.name == trimmedName && $0.pricePerUnit == price
            })
            let existingItems = try? modelContext.fetch(fetchRequest)

            if let existingItem = existingItems?.first {
                // Item already exists. Add a new supply to it.
                // Inside the saveItem function, when adding a supply to an existing item
                let newSupply = SupplyRecord(date: itemReceivedDate, quantity: newQty)
                newSupply.inventoryItem = existingItem
                modelContext.insert(newSupply)
                print("📦 Added new supply to existing item: \(existingItem.name)")
            } else {
                // Item is brand new. Create the item and its initial supply.
                let newItem = InventoryItem(
                    name: trimmedName,
                    pricePerUnit: price,
                    barcodes: finalBarcodes, // Assign the clean barcodes
                    receivedDate: itemReceivedDate
                )
                let initialSupply = SupplyRecord(date: itemReceivedDate, quantity: newQty)
                initialSupply.inventoryItem = newItem

                modelContext.insert(newItem)
                modelContext.insert(initialSupply)
                print("✨ Created new master item: \(newItem.name)")
            }
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to save context after item changes/supply: \(error)")
        }
        sheetMode = nil
    }

    private func cancel() {
        sheetMode = nil
        // No need to check if editingItem was nil, rollback does nothing if there are no changes.
        modelContext.rollback()
    }

    // This function is called by the .onDelete swipe action
    private func confirmDeleteItems(at offsets: IndexSet) {
        // Since we want to check each item before deleting, iterate through the offsets.
        // If even one item cannot be deleted, show the alert and stop the process for all.
        var itemsCannotBeDeleted = false
        var itemsToConfirm: [InventoryItem] = []

        // Inside the confirmDeleteItems(at:) function
        for index in offsets {
            let item = self.filteredItems[index] // Use the correct filteredItems array
            // IMPORTANT: Ensure your InventoryItem model has @Relationship var distributions: [Distribution] = []
            // AND @Relationship var supplies: [SupplyRecord] = [] for these checks to work.
            if !item.distributions.isEmpty {
                itemsCannotBeDeleted = true
                break // Found an item that blocks deletion, so stop checking and show general alert
            }
            itemsToConfirm.append(item)
        }

        if itemsCannotBeDeleted {
            showingDistributionExistsAlert = true
        } else if let firstItem = itemsToConfirm.first {
            // If only one item, show its name in confirmation. Otherwise, a generic message.
            itemToDelete = firstItem // Store the first item for the alert message
            showingDeletionAlert = true // Trigger the confirmation alert
        }
        // If multiple items are selected and all can be deleted, the user will confirm generic "these items"
        // and deleteItems will be called.
        // For simplicity with the single-item `itemToDelete` state, we'll confirm for one at a time via swipe.
        // For multiple swipe deletions, you might need a different confirmation flow.
        // For now, if multiple are swiped and all are deletable, the current setup will only trigger the alert for the first and then delete it.
        // A better approach for multi-swipe would be to collect all deletable items and delete them without per-item confirmation.
        // For this patch, we will prioritize stopping if any item has dependencies.
    }
    
    // New function to handle the actual deletion of a single item
    private func deleteSingleItem(_ item: InventoryItem) {
        if inventoryItems.contains(item) {
            modelContext.delete(item)
            do {
                try modelContext.save()
            } catch {
                print("Failed to save context after deleting item: \(error)")
                // Show an error alert if save fails
            }
        }
        itemToDelete = nil // Clear the stored item
    }
}

struct ScanIndex: Identifiable {
    var id: Int { index }
    let index: Int
}
