//
//  MonthSelectorView.swift
//  BondStoreApp
//
//  Created by Valentyn on 26.06.25.
//

import SwiftUI
import SwiftData

struct MonthSelectorView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @State private var availableMonths: [String] = []
    @State private var selectedMonth: String?
    @State private var showingMonthPicker = false
    @State private var navigateToMainTab = false
    
    func createNewMonth(_ month: String) {
        Task {
            do {
                // Find previous month (max monthID less than the new month)
                let fetchRequest = FetchDescriptor<MonthlyData>(
                    predicate: #Predicate<MonthlyData> { $0.monthID < month },
                    sortBy: [SortDescriptor(\.monthID, order: .reverse)]
                )

                let previousMonths = try modelContext.fetch(fetchRequest)
                let previousMonthData = previousMonths.first

                // Prepare new MonthlyData
                let newMonthData = MonthlyData(monthID: month)

                if let prev = previousMonthData {
                    // Step 1: Copy inventory and build mapping
                    var inventoryMap: [UUID: InventoryItem] = [:]
                    for oldItem in prev.inventoryItems {
                        if oldItem.quantity > 0 {
                            let newItem = oldItem.deepCopy()
                            inventoryMap[oldItem.id] = newItem
                            newMonthData.inventoryItems.append(newItem)
                        }
                    }

                    for oldSeafarer in prev.seafarers {
                        let newSeafarer = oldSeafarer.deepCopy() // Use the correct deepCopy
                        newMonthData.seafarers.append(newSeafarer)
                    }
                }

                modelContext.insert(newMonthData)

                // Save changes
                try modelContext.save()

                DispatchQueue.main.async {
                    loadAvailableMonths()
                    selectedMonth = month
                    appState.selectedMonthID = month
                }
            } catch {
                print("Failed to create new month: \(error)")
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(availableMonths, id: \.self) { month in
                        HStack(spacing: 12) {
                            Text(formattedMonthYear(from: month))
                                .foregroundColor(.primary)
                                .font(selectedMonth == month ? .title3.bold() : .body)
                                .padding(.vertical, 12)
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedMonth == month ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedMonth == month ? Color.blue : .clear, lineWidth: 2)
                                        )
                                )
                                .onTapGesture {
                                    withAnimation(.easeInOut) {
                                        selectedMonth = month
                                    }
                                }

                            ZStack {
                                if selectedMonth == month {
                                    Button(action: {
                                        withAnimation {
                                            appState.selectedMonthID = month
                                            
                                            navigateToMainTab = true
                                        }
                                    }) {
                                        Text("Enter")
                                            .frame(width: 80, height: 44)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                                    .id("Enter-\(month)") // Unique ID for proper animation
                                }
                            }
                            .animation(.easeOut(duration: 0.4), value: selectedMonth)

                        }
                        .animation(.easeInOut(duration: 0.4), value: selectedMonth)
                        .padding(.horizontal)
                        .scrollContentBackground(.hidden) // hides List’s scroll area background

                    }
                    .onDelete(perform: deleteMonths)
                    
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .listRowSeparator(.hidden)
                }
                .scrollContentBackground(.hidden)
                .listRowSeparator(.hidden)
                .listStyle(PlainListStyle())
                Button(action: {
                    showingMonthPicker = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add New Month")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
            }
            
            .navigationTitle("Select Month")
            .sheet(isPresented: $showingMonthPicker) {
                MonthYearPickerView { month in
                    showingMonthPicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        handleNewMonthSelection(month)
                    }
                }
            }
            .onAppear {
                loadAvailableMonths()
                selectedMonth = appState.selectedMonthID

                // 🔄 Recalculate when this view appears again after editing a month
                if let selectedMonthID = appState.selectedMonthID {
                    recalculateFutureMonths(startMonthID: selectedMonthID)
                }
            }

            .onChange(of: appState.selectedMonthID) { newValue, _ in
                if newValue == nil {
                    loadAvailableMonths()
                }
            }
            .alert(isPresented: $appState.showCreateMonthConfirmation) {
                Alert(
                    title: Text("Create New Month?"),
                    message: Text("Previous month’s seafarers and inventory will be copied."),
                    primaryButton: .default(Text("Create")) {
                        if let newMonth = appState.newMonthToCreate {
                            DispatchQueue.main.async {
                                createNewMonth(newMonth)
                            }
                        }
                        appState.showCreateMonthConfirmation = false
                    },
                    secondaryButton: .cancel {
                        appState.showCreateMonthConfirmation = false
                    }
                )
            }
            .navigationDestination(isPresented: $navigateToMainTab) {
                MainTabView()
                    .environmentObject(appState)
            }
        }
    }


    func loadAvailableMonths() {
        do {
            let fetchRequest = FetchDescriptor<MonthlyData>(sortBy: [SortDescriptor(\.monthID)])
            let monthsData = try modelContext.fetch(fetchRequest)
            availableMonths = monthsData.map { $0.monthID }
        } catch {
            print("Failed to fetch months: \(error)")
            availableMonths = []
        }
    }

    func totalDistributed(item: InventoryItem, in month: MonthlyData) -> Int {
        // Fetch and sum all Distribution records tied to this item and month
        let matchingDistributions = month.seafarers
            .flatMap { $0.distributions }
            .filter {
                // This condition checks if the distribution's inventory item (which might be a copied instance)
                // matches the original item ID of the current item being processed.
                let match = $0.inventoryItem?.originalItemID == item.originalItemID
                // Debugging print statement:
                print("🔍 Matching item '\(item.name)' (origID: \(item.originalItemID?.uuidString ?? "nil")) to distribution '\($0.inventoryItem?.name ?? "-")' (origID: \($0.inventoryItem?.originalItemID?.uuidString ?? "nil")), match: \(match)")
                return match
            }

        return matchingDistributions.reduce(0) { $0 + $1.quantity }
    }


    func recalculateFutureMonths(startMonthID: String) {
        Task {
            do {
                let futureRequest = FetchDescriptor<MonthlyData>(
                    predicate: #Predicate<MonthlyData> { $0.monthID > startMonthID },
                    sortBy: [SortDescriptor(\.monthID)]
                )
                let futureMonths = try modelContext.fetch(futureRequest)

                let sourceRequest = FetchDescriptor<MonthlyData>(
                    predicate: #Predicate<MonthlyData> { $0.monthID == startMonthID }
                )
                guard let sourceMonth = try modelContext.fetch(sourceRequest).first else { return }

                // Define a struct to hold all relevant source item properties
                struct SourceItemProperties {
                    let quantity: Int
                    let name: String
                    let pricePerUnit: Double
                    let barcode: String?
                    let receivedDate: Date
                }

                // Create lookup by item original ID from updated source
                let sourceItemsByID = Dictionary(
                    uniqueKeysWithValues: sourceMonth.inventoryItems.map { item in
                        (item.originalItemID ?? item.id, SourceItemProperties(
                            quantity: item.quantity,
                            name: item.name,
                            pricePerUnit: item.pricePerUnit,
                            barcode: item.barcode,
                            receivedDate: item.receivedDate
                        ))
                    }
                )

                for futureMonth in futureMonths {
                    print("📅 Recalculating month: \(futureMonth.monthID)")

                    for item in futureMonth.inventoryItems {
                        print("🔧 Item: \(item.name), origID: \(item.originalItemID?.uuidString ?? "nil")")

                        // Look up all properties from the source month using the originalItemID.
                        if let sourceProps = sourceItemsByID[item.originalItemID ?? item.id] {
                            var changedProperties: [String] = [] // To log what actually changed

                            // 1. Update Quantity (if changed)
                            let usedQty = totalDistributed(item: item, in: futureMonth)
                            let newCalculatedQty = max(sourceProps.quantity - usedQty, 0)
                            if item.quantity != newCalculatedQty {
                                item.quantity = newCalculatedQty
                                changedProperties.append("quantity")
                            }

                            // 2. Update Name (if changed)
                            if item.name != sourceProps.name {
                                item.name = sourceProps.name
                                changedProperties.append("name")
                            }

                            // 3. Update Price Per Unit (if changed)
                            if item.pricePerUnit != sourceProps.pricePerUnit {
                                item.pricePerUnit = sourceProps.pricePerUnit
                                changedProperties.append("pricePerUnit")
                            }

                            // 4. Update Barcode (if changed)
                            if item.barcode != sourceProps.barcode {
                                item.barcode = sourceProps.barcode
                                changedProperties.append("barcode")
                            }

                            // 5. Update Received Date (if changed)
                            if item.receivedDate != sourceProps.receivedDate {
                                item.receivedDate = sourceProps.receivedDate
                                changedProperties.append("receivedDate")
                            }


                            if changedProperties.isEmpty {
                                print("📦 → No properties changed for \(item.name)")
                            } else {
                                print("📦 → Updated properties for \(item.name): \(changedProperties.joined(separator: ", "))")
                                print("    New Values: Qty: \(item.quantity), Name: \(item.name), Price: \(item.pricePerUnit), Barcode: \(item.barcode ?? "nil"), Received Date: \(item.receivedDate)")
                            }

                        } else {
                            print("⚠️ → No match found for \(item.name) (originalItemID: \(item.originalItemID?.uuidString ?? "nil")) in source month \(sourceMonth.monthID)")
                            // Consider what to do if an item from a future month no longer exists in the source month.
                            // Options: Set quantity to 0, remove the item, or leave it as is (current behavior).
                            // For now, we'll just log it.
                        }
                    }
                }

                try modelContext.save()
            } catch {
                print("❌ Error recalculating future months: \(error)")
            }
        }
    }

    func selectMonth(_ month: String) {
        selectedMonth = month
    }

    func handleNewMonthSelection(_ month: String) {
        selectedMonth = month
        if !availableMonths.contains(month) {
            appState.newMonthToCreate = month
            appState.showCreateMonthConfirmation = true
        }
    }

    func deleteMonths(at offsets: IndexSet) {
        for index in offsets {
            let monthToDelete = availableMonths[index]

            // Fetch MonthlyData for this monthToDelete and delete it
            let fetchRequest = FetchDescriptor<MonthlyData>(predicate: #Predicate<MonthlyData> { $0.monthID == monthToDelete })
            if let monthData = try? modelContext.fetch(fetchRequest).first {
                modelContext.delete(monthData)
            }

            availableMonths.remove(at: index)

            if selectedMonth == monthToDelete {
                selectedMonth = nil
                appState.selectedMonthID = nil
            }
        }
    }
}

func formattedMonthYear(from rawString: String) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM"

    guard let date = dateFormatter.date(from: rawString) else {
        return rawString
    }

    dateFormatter.dateFormat = "LLLL yyyy" // Corrected format for month name and year (e.g., "July 2025")
    return dateFormatter.string(from: date)
}
