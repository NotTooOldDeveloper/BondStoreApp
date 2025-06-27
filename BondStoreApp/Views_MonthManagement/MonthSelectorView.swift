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
                        let newItem = oldItem.deepCopy()
                        inventoryMap[oldItem.id] = newItem
                        newMonthData.inventoryItems.append(newItem)
                    }

                    // Step 2: Copy seafarers and their distributions using inventory map
                    for oldSeafarer in prev.seafarers {
                        let newSeafarer = oldSeafarer.deepCopy(using: inventoryMap)
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
        NavigationView {
            VStack {
                List {
                    ForEach(availableMonths, id: \.self) { month in
                        Button {
                            selectMonth(month)
                        } label: {
                            Text(month)
                        }
                    }
                    .onDelete(perform: deleteMonths)
                }
                Button("Change Month") {
                    showingMonthPicker = true
                }
                .padding()

                Button("Enter Bond Store") {
                    if let selected = selectedMonth ?? appState.selectedMonthID {
                        appState.selectedMonthID = selected
                    }
                }
                .disabled(selectedMonth == nil && appState.selectedMonthID == nil)
                .padding()
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
