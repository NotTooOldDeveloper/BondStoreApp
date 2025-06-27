import Foundation
import SwiftData

@Model
class MonthlyData {
    var id: UUID
    var monthID: String // e.g., "2025-06"
    
    @Relationship var seafarers: [Seafarer] = []
    @Relationship var inventoryItems: [InventoryItem] = []
    
    init(monthID: String) {
        self.id = UUID()
        self.monthID = monthID
    }
}
