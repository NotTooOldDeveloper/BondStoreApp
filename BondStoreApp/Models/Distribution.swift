//
//  Distribution.swift
//  BondStoreApp
//
//  Created by Valentyn on 26.06.25.
//

import Foundation
import SwiftData

@Model
class Distribution {
    var id: UUID
    var date: Date
    var itemName: String
    var quantity: Int
    var unitPrice: Double

    @Relationship var seafarer: Seafarer?
    @Relationship var inventoryItem: InventoryItem?

    init(date: Date, itemName: String, quantity: Int, unitPrice: Double, seafarer: Seafarer?, inventoryItem: InventoryItem?) {
        self.id = UUID()
        self.date = date
        self.itemName = itemName
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.seafarer = seafarer
        self.inventoryItem = inventoryItem
    }

    var total: Double {
        Double(quantity) * unitPrice
    }
}

extension Distribution {
    func deepCopy(using inventoryMap: [UUID: InventoryItem], newSeafarer: Seafarer) -> Distribution {
        let matchingItem = inventoryMap.values.first(where: { $0.name == self.itemName })
        return Distribution(
            date: self.date,
            itemName: self.itemName,
            quantity: self.quantity,
            unitPrice: self.unitPrice,
            seafarer: newSeafarer,
            inventoryItem: matchingItem
        )
    }
}
