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
                            .font(.body.bold())
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
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(seafarer.distributions) { dist in
                            VStack(alignment: .leading, spacing: 6) {
                                
                                HStack {
                                    Text(dist.itemName)
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
                        }
                    }
                    .padding(.top, 10) // Add top padding to shift the content slightly downward
                }
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.03),
                            .init(color: .black, location: 0.97),
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            Spacer()

            
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
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

private func formattedMonthName(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "LLLL"
    return formatter.string(from: date)
}
