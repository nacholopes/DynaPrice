import Foundation
import CoreData

enum TriggerType: String, CaseIterable {
    case salesVolume = "salesVolume"
    case competitorPrice = "competitorPrice"
    case timeBasedRule = "timeBasedRule"
    case stockLevel = "stockLevel"
}
