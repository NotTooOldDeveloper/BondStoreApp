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
                // --- BEGIN CHANGE ---
                // Sort the seafarers array by displayID in ascending order
                ForEach(month.seafarers.sorted(using: SortDescriptor(\.displayID)), id: \.id) { seafarer in
                // --- END CHANGE ---
                    VStack(alignment: .leading) {
                        NavigationLink(destination: SeafarerDetailView(seafarer: seafarer, inventoryItems: month.inventoryItems)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("\(seafarer.displayID).")
                                            .bold()
                                        Text(seafarer.name)
                                            .bold()
                                    }
                                    Text(seafarer.rank)
                                        .font(.subheadline)
                                }
                                Spacer()
                                Text("Spent: $\(seafarer.totalSpent, specifier: "%.2f")")
                                    .font(.headline)
                                    .multilineTextAlignment(.trailing)
                                    .frame(alignment: .center)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteSeafarers)
            }
            .navigationTitle("Seafarers")
            .toolbar {
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
