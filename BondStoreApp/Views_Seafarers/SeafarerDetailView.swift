//
//  SeafarerDetailView.swift
//  BondStoreApp
//
//  Created by Valentyn on 26.06.25.
//

import SwiftUI
import SwiftData

struct SeafarerDetailView: View {
    @Bindable var seafarer: Seafarer
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddDistribution = false
    @State private var showingBarcodeScanner = false
    @State private var isEditingSeafarer = false
    @State private var editName = ""
    @State private var editID = "" // This var is correctly used for editing
    @State private var editRank = ""
    @State private var editIsRepresentative = false
    @State private var selectedItem: InventoryItem?
    @State private var quantityString = ""
    @State private var selectedDate = Date()
    
    @State private var distributionToEdit: Distribution?
    @State private var editedQuantityString = ""
    @State private var editedDate = Date()
    @State private var showInventoryAlert = false

    @Query(sort: \InventoryItem.name) private var inventoryItems: [InventoryItem]

    private var startOfMonthDate: Date {
        guard let monthID = seafarer.monthlyData?.monthID else { return .distantFuture }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        // By not setting a timezone, we let it use the user's local timezone, which is correct for UI.
        return formatter.date(from: monthID) ?? .distantFuture
    }

    private var endOfMonthDate: Date {
        // Use the local calendar to find the last day of the month correctly.
        let startDate = startOfMonthDate // Assign directly, no 'guard let' needed.
        guard let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: startDate),
              let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: nextMonth) else {
            return .distantPast
        }
        return lastDay
    }

        private var availableItemsForMonth: [InventoryItem] {
            inventoryItems.filter { $0.receivedDate <= endOfMonthDate }
        }
    
    init(seafarer: Seafarer) {
        self._seafarer = Bindable(wrappedValue: seafarer)
    }

    // Helper function to calculate price with tax for non-representatives
    func priceWithTax(for seafarer: Seafarer, basePrice: Double) -> Double {
        seafarer.isRepresentative ? basePrice : basePrice * 1.10
    }

    func recalculateTotalSpent() {
        seafarer.totalSpent = seafarer.distributions.reduce(0) { partialSum, dist in
            partialSum + Double(dist.quantity) * priceWithTax(for: seafarer, basePrice: dist.unitPrice)
        }
        // Clamp near-zero values to 0 to prevent showing "-0.00"
        if abs(seafarer.totalSpent) < 0.001 {
            seafarer.totalSpent = 0
        }
    }
    
    private func getQuantity(for item: InventoryItem, onOrBefore date: Date) -> Int {
        let itemID = item.id

        let supplyPredicate = #Predicate<SupplyRecord> {
            $0.inventoryItem?.id == itemID && $0.date <= date
        }
        let totalSupplied = (try? modelContext.fetch(FetchDescriptor(predicate: supplyPredicate)))?.reduce(0) { $0 + $1.quantity } ?? 0

        let distributionPredicate = #Predicate<Distribution> {
            $0.inventoryItem?.id == itemID && $0.date <= date
        }
        let totalDistributed = (try? modelContext.fetch(FetchDescriptor(predicate: distributionPredicate)))?.reduce(0) { $0 + $1.quantity } ?? 0

        return totalSupplied - totalDistributed
    }

    var body: some View {
        
        VStack(alignment: .leading) { // Removed 'spacing: 16'
            VStack { // Removed 'spacing: 4'
                Text(seafarer.name)
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)
                Text(seafarer.rank)
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
           

            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.3))
                .overlay(
                    HStack {
                       
                        Text("Total spent in \(formattedMonthName(from: startOfMonthDate))")
                            .font(.title3.bold())
                            .foregroundColor(Color("Name1"))
                        Spacer()
                        Text("$\(seafarer.totalSpent, specifier: "%.2f")")
                            .font(.title3.bold())
                            .foregroundColor(Color("Sum"))
                    }
                    .padding(.horizontal) // Retained horizontal padding for internal content readability
                )
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                // Removed .padding(.vertical, 0) as it adds 0 padding which is effectively no padding.

            // The main list of distributions
            if seafarer.distributions.isEmpty {
                Text("No distributions yet.")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                List {
                    // Sorting distributions by date, as discussed previously
                    ForEach(seafarer.distributions.sorted(using: SortDescriptor(\.date)), id: \.id) { dist in
                        Button {
                            distributionToEdit = dist
                            editedQuantityString = "\(dist.quantity)"
                            editedDate = dist.date
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(dist.inventoryItem?.name ?? dist.itemName)
                                        .font(.headline)
                                        .bold()
                                    Spacer()
                                    let taxedTotal = Double(dist.quantity) * priceWithTax(for: seafarer, basePrice: dist.unitPrice)
                                    Text("Total: $\(taxedTotal, specifier: "%.2f")")
                                        .bold()
                                        .foregroundColor(Color("Sum"))
                                }
                                HStack {
                                    Text(dist.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("Qty: \(dist.quantity)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .swipeActions(edge: .trailing) {
                            // Inside the .swipeActions modifier
                            Button(role: .destructive) {

                                seafarer.totalSpent -= Double(dist.quantity) * priceWithTax(for: seafarer, basePrice: dist.unitPrice)
                                // Clamp near-zero values to 0
                                if abs(seafarer.totalSpent) < 0.001 {
                                    seafarer.totalSpent = 0
                                }

                                if let index = seafarer.distributions.firstIndex(of: dist) {
                                    seafarer.distributions.remove(at: index)
                                    modelContext.delete(dist)
                                    try? modelContext.save()
                                }
                            } label: {
                                Text("Delete")
                            }
                        }
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(PlainListStyle())
            }

            Spacer()
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    Spacer()
                    // Inside the .toolbar, in the Button's action closure
                    Button(action: {
                        // Reset fields for a fresh form
                        self.selectedItem = nil
                        self.quantityString = ""

                        // Set default date
                        let today = Date()
                        if today >= startOfMonthDate && today <= endOfMonthDate {
                            self.selectedDate = today
                        } else {
                            self.selectedDate = startOfMonthDate
                        }

                        // Show the sheet
                        self.showingAddDistribution = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                            Text("Add Distribution")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 0.2), value: showingAddDistribution)
                    }
                    Spacer()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    // Initialize state variables with current seafarer data
                    editID = seafarer.displayID
                    editName = seafarer.name
                    editRank = seafarer.rank
                    editIsRepresentative = seafarer.isRepresentative
                    isEditingSeafarer = true
                }
            }
        }
        .sheet(isPresented: $showingAddDistribution) {
            NavigationView {
                Form {
                    Section(header: Text("Select Item")) {
                        Picker("Item", selection: $selectedItem) {
                            Text("Select an item").tag(Optional<InventoryItem>(nil))
                            ForEach(availableItemsForMonth, id: \.id) { item in
                                Text(item.name).tag(Optional(item))
                            }
                        }
                    }

                    TextField("Quantity", text: $quantityString)
                        .keyboardType(.numberPad)
                    DatePicker("Date", selection: $selectedDate, in: startOfMonthDate...endOfMonthDate, displayedComponents: .date)
                }
                .navigationTitle("New Distribution")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            // Inside the "Add" button for a new distribution
                            guard
                                let selectedItem = selectedItem,
                                let qty = Int(quantityString),
                                qty > 0
                            else {
                                // Return early if input is invalid
                                return
                            }

                            // For the check, use the very end of the selected day to include all same-day supplies.
                            let endOfSelectedDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: selectedDate))?.addingTimeInterval(-1) ?? selectedDate
                            guard getQuantity(for: selectedItem, onOrBefore: endOfSelectedDay) >= qty else {
                                showInventoryAlert = true // Show an alert if not enough stock
                                return
                            }

                            let distribution = Distribution(
                                date: selectedDate,
                                itemName: selectedItem.name, // Still using snapshot for item name
                                quantity: qty,
                                unitPrice: selectedItem.pricePerUnit, // Still using snapshot for unit price
                                seafarer: seafarer,
                                inventoryItem: selectedItem
                            )
                            print("🪪 Creating distribution for item: \(selectedItem.name), originalItemID: \(selectedItem.originalItemID?.uuidString ?? "nil")")
                            modelContext.insert(distribution)


                            // Update seafarer's total spent
                            seafarer.totalSpent += Double(qty) * priceWithTax(for: seafarer, basePrice: selectedItem.pricePerUnit)
                            
                            // --- BEGIN ADDED SAVE FOR NEW DISTRIBUTION ---
                            try? modelContext.save() // Save changes to the model context
                            // --- END ADDED SAVE FOR NEW DISTRIBUTION ---

                            showingAddDistribution = false
                        }
                        .disabled(
                            inventoryItems.isEmpty ||
                            Int(quantityString) == nil ||
                            Int(quantityString)! <= 0
                        )
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingAddDistribution = false
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        HStack {
                            Spacer()
                            Button(action: {
                                showingBarcodeScanner = true
                            }) {
                                HStack {
                                    Image(systemName: "barcode.viewfinder")
                                    Text("Scan Barcode")
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            Spacer()
                        }
                    }
                }
                .sheet(isPresented: $showingBarcodeScanner) {
                    BarcodeScannerView(
                        dismissBoth: $showingAddDistribution,
                        // Pass the date range properties
                        startOfMonth: startOfMonthDate,
                        endOfMonth: endOfMonthDate
                    ) { scannedDistributions in
                        for dist in scannedDistributions {
                            dist.seafarer = seafarer
                            seafarer.distributions.append(dist)
                            seafarer.totalSpent += Double(dist.quantity) * priceWithTax(for: seafarer, basePrice: dist.unitPrice)
                            modelContext.insert(dist) // Ensure scanned distributions are inserted
                        }
                        // --- BEGIN ADDED SAVE FOR SCANNED DISTRIBUTIONS ---
                        try? modelContext.save() // Save all scanned distributions and seafarer updates
                        // --- END ADDED SAVE FOR SCANNED DISTRIBUTIONS ---
                    }
                }
            }
        }
        .sheet(item: $distributionToEdit) { dist in
            NavigationView {
                Form {
                    Section {
                        HStack {
                            Text(dist.inventoryItem?.name ?? dist.itemName)
                                .font(.headline)
                        }
                    }
                    DatePicker(selection: $editedDate, in: startOfMonthDate...endOfMonthDate, displayedComponents: .date) {
                        Text("Date")
                            .font(.headline)
                    }
                    .frame(height: 50)
                    TextField("Quantity", text: $editedQuantityString)
                        .keyboardType(.numberPad)
                }
                .navigationTitle("Edit Distribution")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            guard let newQuantity = Int(editedQuantityString), newQuantity > 0 else {
                                return
                            }
                            let quantityDifference = newQuantity - dist.quantity
                            if let inventoryItem = dist.inventoryItem {

                                let endOfEditedDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: editedDate))?.addingTimeInterval(-1) ?? editedDate
                                if getQuantity(for: inventoryItem, onOrBefore: endOfEditedDay) < quantityDifference {
                                    showInventoryAlert = true
                                    return
                                }

                            }
                            // Inside the .sheet(item: $distributionToEdit) modifier, in the "Save" button
                            seafarer.totalSpent += Double(quantityDifference) * priceWithTax(for: seafarer, basePrice: dist.unitPrice)
                            // Clamp near-zero values to 0
                            if abs(seafarer.totalSpent) < 0.001 {
                                seafarer.totalSpent = 0
                            }
                            dist.quantity = newQuantity
                            dist.date = editedDate
                            // --- BEGIN ADDED SAVE FOR EDITING DISTRIBUTION ---
                            try? modelContext.save() // Save changes to the distribution and related models
                            // --- END ADDED SAVE FOR EDITING DISTRIBUTION ---
                            distributionToEdit = nil
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            distributionToEdit = nil
                        }
                    }
                }
            }
            .alert("Not enough inventory", isPresented: $showInventoryAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You don't have enough of this item in inventory to increase the quantity.")
            }
        }
        .sheet(isPresented: $isEditingSeafarer) {
            NavigationView {
                Form {
                    TextField("ID", text: $editID)
                    TextField("Name", text: $editName)
                    TextField("Rank", text: $editRank)
                    Toggle("Is Representative", isOn: $editIsRepresentative)
                }
                .navigationTitle("Edit Seafarer")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            seafarer.name = editName
                            seafarer.displayID = editID
                            seafarer.rank = editRank
                            seafarer.isRepresentative = editIsRepresentative
                            recalculateTotalSpent()
                            try? modelContext.save() // THIS IS THE CRUCIAL LINE!
                            isEditingSeafarer = false
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isEditingSeafarer = false
                        }
                    }
                }
            }
        }
    }
}

private func formattedMonthName(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "LLLL"
    return formatter.string(from: date)
}
