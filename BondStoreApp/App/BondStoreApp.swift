//
//  BondStoreApp.swift
//  BondStoreApp
//here testing commit
//  Created by Valentyn on 26.06.25.
//

import SwiftUI
import SwiftData

@main
struct BondStoreApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MonthSelectorView()
                .environmentObject(appState)
        }
        .modelContainer(for: [
            MonthlyData.self,
            Seafarer.self,
            InventoryItem.self,
            Distribution.self,
            SupplyRecord.self
        ])
    }
}
