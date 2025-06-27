//
//  Seafarer.swift
//  BondStoreApp
//
//  Created by Valentyn on 26.06.25.
//

import Foundation
import SwiftData

@Model
class Seafarer {
    var id: UUID
    var displayID: String
    var name: String
    var rank: String
    var totalSpent: Double

    @Relationship var distributions: [Distribution] = []

    init(displayID: String, name: String, rank: String, totalSpent: Double = 0) {
        self.id = UUID()
        self.displayID = displayID
        self.name = name
        self.rank = rank
        self.totalSpent = totalSpent
    }
}

extension Seafarer {
    func deepCopy(using inventoryMap: [UUID: InventoryItem]) -> Seafarer {
        let clone = Seafarer(displayID: self.displayID, name: self.name, rank: self.rank, totalSpent: 0)
        clone.distributions = [] // ← start fresh, no distributions copied
        return clone
    }
}

