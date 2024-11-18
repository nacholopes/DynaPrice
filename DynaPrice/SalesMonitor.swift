import Foundation
import CoreData

struct SaleRecord: Identifiable {
    let id = UUID()
    let date: Date
    let quantity: Int
    let hourPeriod: Int
    let productEAN: String
    let unitPrice: Double
}
    
    func analyzeSales(_ sales: [SaleRecord], for product: Product) -> PriceSuggestion? {
        return nil
    }
