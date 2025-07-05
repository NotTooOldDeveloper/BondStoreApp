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
    var isRepresentative: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Distribution.seafarer)
    var distributions: [Distribution] = []

    var monthlyData: MonthlyData?
    
    init(displayID: String, name: String, rank: String, totalSpent: Double = 0, isRepresentative: Bool = false) {
        self.id = UUID()
        self.displayID = displayID
        self.name = name
        self.rank = rank
        self.totalSpent = totalSpent
        self.isRepresentative = isRepresentative
    }
}

extension Seafarer {
    func deepCopy() -> Seafarer {
        let clone = Seafarer(displayID: self.displayID, name: self.name, rank: self.rank, totalSpent: 0)
        clone.distributions = [] // ← start fresh, no distributions copied
        return clone
    }
}
