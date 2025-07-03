//
//  SupplyRecord.swift
//  BondStoreApp
//here testing commit
//  Created by Valentyn on 26.06.25.
//

import Foundation
import SwiftData

@Model
class SupplyRecord {
    var id: UUID
    var date: Date
    var quantity: Int

    // MARK: - PATCH APPLIED HERE
    // When an InventoryItem is deleted, also delete its associated SupplyRecords.
    @Relationship(deleteRule: .cascade)
    var inventoryItem: InventoryItem?

    init(date: Date, quantity: Int) {
        self.id = UUID()
        self.date = date
        self.quantity = quantity
    }
}

extension SupplyRecord {
    func deepCopy(for newItem: InventoryItem) -> SupplyRecord {
        let copy = SupplyRecord(date: self.date, quantity: self.quantity)
        copy.inventoryItem = newItem
        return copy
    }
}
