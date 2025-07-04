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
    var quantity: Int
    var pricePerUnit: Double
    var barcode: String?
    var receivedDate: Date
    var originalItemID: UUID? // This should be initialized for new items

    // MARK: - Relationships (Crucial for deletion logic)

    // Ensure the 'inverse' is specified for both relationships
    @Relationship(inverse: \SupplyRecord.inventoryItem) // Added inverse
    var supplies: [SupplyRecord] = []

    // 🔴 YOU NEED TO ADD THIS LINE 🔴
    @Relationship(inverse: \Distribution.inventoryItem)
    var distributions: [Distribution] = []

    // MARK: - Initializer

    init(name: String, quantity: Int, pricePerUnit: Double, barcode: String? = nil, receivedDate: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.pricePerUnit = pricePerUnit
        self.barcode = barcode
        self.receivedDate = receivedDate
        self.originalItemID = self.id // Initialize originalItemID for new items here
    }
}

// MARK: - Extensions (Remain largely the same, but deepCopy needs to handle distributions if you use them)

extension InventoryItem {
    func deepCopy() -> InventoryItem {
        let clone = InventoryItem(
            name: self.name,
            quantity: self.quantity,
            pricePerUnit: self.pricePerUnit,
            barcode: self.barcode,
            receivedDate: self.receivedDate
        )
        clone.originalItemID = self.originalItemID ?? self.id
        clone.supplies = self.supplies.map { $0.deepCopy(for: clone) }
        // If you ever deep-copy InventoryItem and need to copy distributions, you'd add:
        // clone.distributions = self.distributions.map { $0.deepCopy(for: clone) } // Assuming Distribution has a deepCopy
        return clone
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
