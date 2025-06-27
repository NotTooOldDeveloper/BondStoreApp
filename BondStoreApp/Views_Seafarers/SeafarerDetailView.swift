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

    @State private var isEditingSeafarer = false
    @State private var editName = ""
    @State private var editID = ""
    @State private var editRank = ""

    // Form state
    @State private var selectedItem: InventoryItem?
    @State private var quantityString = ""
    @State private var selectedDate = Date()

    var inventoryItems: [InventoryItem]

    init(seafarer: Seafarer, inventoryItems: [InventoryItem]) {
        self._seafarer = Bindable(wrappedValue: seafarer)
        self.inventoryItems = inventoryItems
        self._selectedItem = State(initialValue: inventoryItems.first)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(seafarer.name)
                .font(.title)
                .bold()
            Text("ID: \(seafarer.displayID)")
            Text("Rank: \(seafarer.rank)")
            Text("Total Spent: €\(seafarer.totalSpent, specifier: "%.2f")")

            Divider()

            Text("Distributions:")
                .font(.headline)

            if seafarer.distributions.isEmpty {
                Text("No distributions yet.")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                List {
                    ForEach(seafarer.distributions) { distribution in
                        VStack(alignment: .leading) {
                            Text("\(distribution.itemName) x\(distribution.quantity)")
                            Text("Date: \(distribution.date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                            Text("Total: €\(distribution.total, specifier: "%.2f")")
                                .font(.caption)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }

            Spacer()

            Button("Add Distribution") {
                showingAddDistribution = true
                if let firstItem = inventoryItems.first {
                    selectedItem = firstItem
                }
                quantityString = ""
                selectedDate = Date()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
        .navigationTitle("Seafarer Detail")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    editName = seafarer.name
                    editID = seafarer.displayID
                    editRank = seafarer.rank
                    isEditingSeafarer = true
                }
            }
        }
        .sheet(isPresented: $showingAddDistribution) {
            NavigationView {
                Form {
                    Picker("Item", selection: $selectedItem) {
                        ForEach(inventoryItems, id: \.id) { item in
                            Text(item.name).tag(Optional(item))
                        }
                    }
                    .onChange(of: selectedItem) { _, selectedItem in
                        print("Selected item changed to: \(selectedItem?.name ?? "nil")")
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
                }
            }
        }
        .sheet(isPresented: $isEditingSeafarer) {
            NavigationView {
                Form {
                    TextField("Name", text: $editName)
                    TextField("ID", text: $editID)
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
