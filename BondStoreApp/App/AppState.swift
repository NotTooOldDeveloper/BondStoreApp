//
//  AppState.swift
//  BondStoreApp
//
//  Created by Valentyn on 26.06.25.
//

import Foundation
import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var selectedMonthID: String? {
        didSet {
            if let month = selectedMonthID {
                UserDefaults.standard.set(month, forKey: "lastSelectedMonth")
            }
        }
    }
    
    @Published var showCreateMonthConfirmation = false
    @Published var newMonthToCreate: String?

    init() {
        selectedMonthID = UserDefaults.standard.string(forKey: "lastSelectedMonth")
    }
}
