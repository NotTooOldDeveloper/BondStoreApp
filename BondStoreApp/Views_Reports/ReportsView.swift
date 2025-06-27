//
//  ReportsView.swift
//  BondStoreApp
//
//  Created by Valentyn on 26.06.25.
//


import SwiftUI

struct ReportsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            Text("Reports View (coming soon)")
                .navigationTitle("Reports")
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
                }
        }
    }
}
