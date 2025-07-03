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
            List {
                NavigationLink("Crew Distribution Report") {
                    CrewDistributionReportView()
                }
                NavigationLink("Inventory Stock Report") { // New link for the inventory report
                    InventoryReportView()
                                }
            }
            .navigationTitle("Reports")
        }
    }
}
