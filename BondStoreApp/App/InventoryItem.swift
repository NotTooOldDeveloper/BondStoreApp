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
    var barcode: String?
    var receivedDate: Date
    var originalItemID: UUID? // This should be initialized for new items

    // Ensure the 'inverse' is specified for both relationships
    @Relationship(deleteRule: .cascade, inverse: \SupplyRecord.inventoryItem)
    var supplies: [SupplyRecord] = []

    @Relationship(deleteRule: .nullify, inverse: \Distribution.inventoryItem)
    var distributions: [Distribution] = []

    // var monthlyData: MonthlyData? - not required in new model

    init(name: String, pricePerUnit: Double, barcode: String? = nil, receivedDate: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.pricePerUnit = pricePerUnit
        self.barcode = barcode
        self.receivedDate = receivedDate
        self.originalItemID = self.id // Initialize originalItemID for new items here
    }
}

//extension InventoryItem {
//    func deepCopy() -> InventoryItem {
//        let clone = InventoryItem(
//            name: self.name,
//            quantity: self.quantity,
//            pricePerUnit: self.pricePerUnit,
//            barcode: self.barcode,
//            receivedDate: self.receivedDate
//        )
//        clone.originalItemID = self.originalItemID ?? self.id
//        clone.supplies = self.supplies.map { $0.deepCopy(for: clone) }
//        // If you ever deep-copy InventoryItem and need to copy distributions, you'd add:
//        // clone.distributions = self.distributions.map { $0.deepCopy(for: clone) } // Assuming Distribution has a deepCopy
//        return clone
//    }
//}

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
