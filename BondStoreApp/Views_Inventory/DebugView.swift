import SwiftUI
import SwiftData

struct DebugView: View {
    // 1. Fetch all the different types of data from your database
    @Query private var months: [MonthlyData]
    @Query private var inventoryItems: [InventoryItem]
    @Query private var distributions: [Distribution]
    @Query private var supplies: [SupplyRecord]
    @Query private var seafarers: [Seafarer]

    var body: some View {
        NavigationStack {
            List {
                // 2. Show a high-level summary
                Section("📊 Database Summary") {
                    Text("Months Recorded: \(months.count)")
                    Text("Master Inventory Items: \(inventoryItems.count)")
                    Text("Total Seafarer Records: \(seafarers.count)")
                    Text("Total Supply Records: \(supplies.count)")
                    Text("Total Distribution Records: \(distributions.count)")
                }

                // 3. List all master inventory items
                Section("📦 Master Inventory (\(inventoryItems.count))") {
                    if inventoryItems.isEmpty {
                        Text("No master items found.")
                    } else {
                        ForEach(inventoryItems) { item in
                            VStack(alignment: .leading) {
                                Text(item.name).bold()
                                Text("ID: \(item.id.uuidString.prefix(8))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // 4. List all months and the seafarers in them
                Section("🗓️ Monthly Data (\(months.count))") {
                    if months.isEmpty {
                        Text("No months created.")
                    } else {
                        ForEach(months) { month in
                            VStack(alignment: .leading) {
                                Text(month.monthID).bold()
                                Text("\(month.seafarers.count) seafarers recorded")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Debug Info")
        }
    }
}//
//  DebugView.swift
//  BondStoreApp
//
//  Created by Valentyn on 05.07.25.
//

