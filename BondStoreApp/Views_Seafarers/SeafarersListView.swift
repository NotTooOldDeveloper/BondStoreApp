//
//  SeafarersListView.swift
//  BondStoreApp
//
//  Created by Valentyn on 26.06.25.
//

import SwiftUI
import SwiftData

struct SeafarersListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    var month: MonthlyData

    @State private var showingAddSeafarer = false
    @State private var newID = ""
    @State private var newName = ""
    @State private var newRank = ""

    var body: some View {
        NavigationView {
            List {
                ForEach(month.seafarers) { seafarer in
                    VStack(alignment: .leading) {
                        Text("DEBUG: \(seafarer.name), distributions count: \(seafarer.distributions.count)")
                            .font(.caption)
                            .foregroundColor(.red)
                        NavigationLink(destination: SeafarerDetailView(seafarer: seafarer, inventoryItems: month.inventoryItems)) {
                            VStack(alignment: .leading) {
                                Text(seafarer.name)
                                    .font(.headline)
                                Text("ID: \(seafarer.displayID), Rank: \(seafarer.rank)")
                                    .font(.subheadline)
                                Text("Spent: €\(seafarer.totalSpent, specifier: "%.2f")")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteSeafarers)
            }
            .navigationTitle("Seafarers")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        appState.selectedMonthID = nil
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Month")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddSeafarer = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSeafarer) {
                NavigationView {
                    Form {
                        TextField("ID", text: $newID)
                        TextField("Name", text: $newName)
                        TextField("Rank", text: $newRank)
                    }
                    .navigationTitle("New Seafarer")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                let seafarer = Seafarer(
                                    displayID: newID,
                                    name: newName,
                                    rank: newRank
                                )
                                month.seafarers.append(seafarer)
                                modelContext.insert(seafarer)
                                showingAddSeafarer = false
                                newID = ""
                                newName = ""
                                newRank = ""
                            }
                            .disabled(newID.isEmpty || newName.isEmpty || newRank.isEmpty)
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingAddSeafarer = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func deleteSeafarers(at offsets: IndexSet) {
        for index in offsets {
            let seafarer = month.seafarers[index]
            modelContext.delete(seafarer)
        }
    }
}
