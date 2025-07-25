import Foundation
import SwiftData

@Model
class MonthlyData {
    var id: UUID
    var monthID: String // e.g., "2025-06"
    
    @Relationship(deleteRule: .cascade, inverse: \Seafarer.monthlyData)
    var seafarers: [Seafarer] = []
    
    init(monthID: String) {
        self.id = UUID()
        self.monthID = monthID
    }
}
