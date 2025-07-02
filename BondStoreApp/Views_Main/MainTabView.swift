//
//  MainTabView.swift
//  BondStoreApp
//
//  Created by Valentyn on 26.06.25.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @State private var currentMonthData: MonthlyData?

    var body: some View {
        TabView {
            if let month = currentMonthData {
                SeafarersListView(month: month)
                    .tabItem {
                        Label("Seafarers", systemImage: "person.3.fill")
                    }
            } else {
                Text("No month selected")
                    .tabItem {
                        Label("Seafarers", systemImage: "person.3.fill")
                    }
            }

            if let month = currentMonthData {
                InventoryListView(month: month)
                    .tabItem {
                        Label("Inventory", systemImage: "shippingbox.fill")
                    }
            } else {
                Text("No month selected")
                    .tabItem {
                        Label("Inventory", systemImage: "shippingbox.fill")
                    }
            }

            ReportsView()
                .tabItem {
                    Label("Reports", systemImage: "doc.plaintext")
                }
        }
        .background(Color("AppBackground"))
        .ignoresSafeArea(.all) // Ensures it covers the entire screen
        .onAppear {
            DispatchQueue.main.async {
                loadCurrentMonth()
            }
        }
        .onChange(of: appState.selectedMonthID) {
            DispatchQueue.main.async {
                loadCurrentMonth()
            }
        }
    }

    private func loadCurrentMonth() {
        guard let monthID = appState.selectedMonthID else {
            currentMonthData = nil
            return
        }
        let fetchRequest = FetchDescriptor<MonthlyData>(predicate: #Predicate<MonthlyData> { $0.monthID == monthID })
        do {
            let results = try modelContext.fetch(fetchRequest)
            currentMonthData = results.first
        } catch {
            print("Failed to load current month data: \(error)")
            currentMonthData = nil
        }
    }
}
