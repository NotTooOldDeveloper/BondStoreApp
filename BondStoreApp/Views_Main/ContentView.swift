//
//  ContentView.swift
//  BondStoreApp
//
//  Created by Valentyn on 26.06.25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if let _ = appState.selectedMonthID {
            MainTabView()
        } else {
            MonthSelectorView()
        }
    }
}
