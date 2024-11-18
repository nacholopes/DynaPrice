import Foundation

enum DynaPriceModels {
    struct SaleRecord: Identifiable {
        let id = UUID()
        let date: Date
        let quantity: Int
        let hourPeriod: Int
        let productEAN: String
        let unitPrice: Double
    }
    
    enum TriggerType: String, CaseIterable {
        case salesVolume = "salesVolume"
        case competitorPrice = "competitorPrice"
        case timeBasedRule = "timeBasedRule"
        case stockLevel = "stockLevel"
    }
    
    struct SalesMetrics {
        let hourlyVolume: [Int: Int]  // hour -> quantity
        let averageHourlyVolume: Double
        let percentageChange: Double
        let timeWindow: Int
    }
}

//// Type aliases for convenience
//typealias SaleRecord = DynaPriceModels.SaleRecord
//typealias TriggerType = DynaPriceModels.TriggerType
//typealias SalesMetrics = DynaPriceModels.SalesMetrics
