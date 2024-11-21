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
        case timeBasedRule = "timeBasedRule"
    }
    
    struct SalesMetrics {
        let hourlyVolume: Int
        let averageQuantity: Double
        let percentageChange: Double
    }
}
