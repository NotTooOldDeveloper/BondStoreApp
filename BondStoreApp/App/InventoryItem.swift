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
    

    @Relationship var supplies: [SupplyRecord] = []

    init(name: String, quantity: Int, pricePerUnit: Double, barcode: String? = nil) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.pricePerUnit = pricePerUnit
        self.barcode = barcode
    }
}

extension InventoryItem {
    func deepCopy() -> InventoryItem {
        let clone = InventoryItem(
            name: self.name,
            quantity: self.quantity,
            pricePerUnit: self.pricePerUnit,
            barcode: self.barcode
        )
        clone.supplies = self.supplies.map { $0.deepCopy(for: clone) }
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
