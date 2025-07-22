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
                    // Copy seafarers with reset totals, filtering out representatives.
                    for oldSeafarer in prev.seafarers.filter({ !$0.isRepresentative }) {
                        let newSeafarer = oldSeafarer.deepCopy()
                        newSeafarer.monthlyData = newMonthData // Set the inverse relationship
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
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
        let monthsToDelete = offsets.map { availableMonths[$0] }

        for monthID in monthsToDelete {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"

            // Ensure we have a valid date range before proceeding
            guard let startDate = formatter.date(from: monthID),
                  let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) else {
                print("Error: Could not determine date range for \(monthID).")
                continue // Skip to the next month
            }

            // 1. Delete all Supply Records within the month
            let supplyPredicate = #Predicate<SupplyRecord> {
                $0.date >= startDate && $0.date < endDate
            }
            if let suppliesToDelete = try? modelContext.fetch(FetchDescriptor(predicate: supplyPredicate)) {
                suppliesToDelete.forEach { modelContext.delete($0) }
            }

            // 2. Delete master Inventory Items CREATED within the month
            let itemPredicate = #Predicate<InventoryItem> {
                $0.receivedDate >= startDate && $0.receivedDate < endDate
            }
            if let itemsToDelete = try? modelContext.fetch(FetchDescriptor(predicate: itemPredicate)) {
                itemsToDelete.forEach { modelContext.delete($0) }
            }

            // 3. Delete the MonthlyData object
            // This cascades to Seafarers and their Distributions
            let monthPredicate = #Predicate<MonthlyData> { $0.monthID == monthID }
            if let monthData = try? modelContext.fetch(FetchDescriptor(predicate: monthPredicate)).first {
                modelContext.delete(monthData)
            }
        }

        // Save changes, reload the UI, and reset selection
        do {
            try modelContext.save()
        } catch {
            print("Failed to save context after comprehensive delete: \(error)")
        }

        loadAvailableMonths()

        if !availableMonths.contains(selectedMonth ?? "") {
            selectedMonth = availableMonths.last
            appState.selectedMonthID = availableMonths.last
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
