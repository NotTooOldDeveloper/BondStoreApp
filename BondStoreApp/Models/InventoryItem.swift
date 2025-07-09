//
//  InventoryItem.swift
//  BondStoreApp
//
//  Created by Valentyn on 26.06.25.
//

import Foundation
import SwiftData

@Model
class InventoryItem {
    var id: UUID
    var name: String
    var pricePerUnit: Double
    var barcodes: [String] = [] // Changed to an array of strings
    var receivedDate: Date
    var originalItemID: UUID? // This should be initialized for new items

    // Ensure the 'inverse' is specified for both relationships
    @Relationship(deleteRule: .cascade, inverse: \SupplyRecord.inventoryItem)
    var supplies: [SupplyRecord] = []

    @Relationship(deleteRule: .nullify, inverse: \Distribution.inventoryItem)
    var distributions: [Distribution] = []

    // var monthlyData: MonthlyData? - not required in new model

    init(name: String, pricePerUnit: Double, barcodes: [String] = [], receivedDate: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.pricePerUnit = pricePerUnit
        self.barcodes = barcodes
        self.receivedDate = receivedDate
        self.originalItemID = self.id // This line was missing
    }
}

extension InventoryItem: Equatable {
    static func == (lhs: InventoryItem, rhs: InventoryItem) -> Bool {
        lhs.id == rhs.id
    }
}

extension InventoryItem: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
