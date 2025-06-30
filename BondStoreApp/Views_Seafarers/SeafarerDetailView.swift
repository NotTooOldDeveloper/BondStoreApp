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
    @State private var editID = ""
    @State private var editRank = ""

    // Form state
    @State private var selectedItem: InventoryItem?
    @State private var quantityString = ""
    @State private var selectedDate = Date()
    
    @State private var distributionToEdit: Distribution?
    @State private var editedQuantityString = ""
    @State private var editedDate = Date()
    @State private var showInventoryAlert = false

    var inventoryItems: [InventoryItem]

    init(seafarer: Seafarer, inventoryItems: [InventoryItem]) {
        self._seafarer = Bindable(wrappedValue: seafarer)
        self.inventoryItems = inventoryItems
        self._selectedItem = State(initialValue: nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 4) {
                Text(seafarer.name)
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)
                Text(seafarer.rank)
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    HStack {
                        Text("Total spent in \(formattedMonthName(from: Date()))")
                            .font(.title3.bold())
                            .foregroundColor(.black)
                        Spacer()
                        Text("$\(seafarer.totalSpent, specifier: "%.2f")")
                            .font(.title3.bold())
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .padding(.vertical, 0)

            
            
            if seafarer.distributions.isEmpty {
                Text("No distributions yet.")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                List {
                    ForEach(seafarer.distributions) { dist in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(dist.inventoryItem?.name ?? dist.itemName)
                                    .font(.headline)
                                    .bold()
                                Spacer()
                                Text("Total: $\(dist.total, specifier: "%.2f")")
                                    .bold()
                                    .foregroundColor(Color.black)
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
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)) // reduce vertical spacing
                        .swipeActions(edge: .trailing) {
                            Button("Edit") {
                                distributionToEdit = dist
                                editedQuantityString = "\(dist.quantity)"
                                editedDate = dist.date
                            }
                            .tint(.blue)

                            Button(role: .destructive) {
                                dist.inventoryItem?.quantity += dist.quantity
                                seafarer.totalSpent -= Double(dist.quantity) * dist.unitPrice
                                if let index = seafarer.distributions.firstIndex(of: dist) {
                                    seafarer.distributions.remove(at: index)
                                    modelContext.delete(dist)
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
                    Button(action: { showingAddDistribution = true }) {
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
                    editID = seafarer.displayID
                    editName = seafarer.name
                    editRank = seafarer.rank
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
                            ForEach(inventoryItems, id: \.id) { item in
                                Text(item.name).tag(Optional(item))
                            }
                        }
                    }

                    TextField("Quantity", text: $quantityString)
                        .keyboardType(.numberPad)
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                }
                .navigationTitle("New Distribution")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            guard
                                let selectedItem = selectedItem,
                                let qty = Int(quantityString),
                                qty > 0,
                                selectedItem.quantity >= qty
                            else {
                                return
                            }


                            let distribution = Distribution(
                                date: selectedDate,
                                itemName: selectedItem.name,
                                quantity: qty,
                                unitPrice: selectedItem.pricePerUnit,
                                seafarer: seafarer,
                                inventoryItem: selectedItem
                            
                            )
                            modelContext.insert(distribution)

                            // Link distribution to seafarer
                            seafarer.distributions.append(distribution)

                            // Update inventory quantity
                            selectedItem.quantity -= qty

                            // Update seafarer's total spent
                            seafarer.totalSpent += Double(qty) * selectedItem.pricePerUnit

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
                        inventoryItems: inventoryItems
                    ) { scannedDistributions in
                        for dist in scannedDistributions {
                            dist.seafarer = seafarer
                            seafarer.distributions.append(dist)
                            seafarer.totalSpent += Double(dist.quantity) * dist.unitPrice
                        }
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
                    DatePicker(selection: $editedDate, displayedComponents: .date) {
                        Text("Date")
                            .font(.headline)
                    }
                    .frame(height: 50)
                    HStack {
                        Text("Quantity")
                            .font(.headline)
                        Spacer()
                        Picker("Quantity", selection: $editedQuantityString) {
                            ForEach(1..<101) { qty in
                                Text("\(qty)").tag("\(qty)")
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100, height: 50)
                        .clipped()
                    }
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
                                if inventoryItem.quantity < quantityDifference {
                                    showInventoryAlert = true
                                    return
                                }
                                inventoryItem.quantity -= quantityDifference
                            }
                            seafarer.totalSpent += Double(quantityDifference) * dist.unitPrice
                            dist.quantity = newQuantity
                            dist.date = editedDate
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
                }
                .navigationTitle("Edit Seafarer")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            seafarer.name = editName
                            seafarer.displayID = editID
                            seafarer.rank = editRank
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
