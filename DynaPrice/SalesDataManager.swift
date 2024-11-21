import Foundation
import CoreData

class SalesDataManager {
    private let managedObjectContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.managedObjectContext = context
    }
    
    func fetchRecentSales(for ean: String, timeWindow: Int = 24) -> [DynaPriceModels.SaleRecord] {
        let fetchRequest = NSFetchRequest<Sale>(entityName: "Sale")
        let thresholdDate = Calendar.current.date(byAdding: .hour, value: -timeWindow, to: Date()) ?? Date()
        
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "ean == %@", ean),
            NSPredicate(format: "date >= %@", thresholdDate as NSDate)
        ])
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Sale.date, ascending: false)]
        
        do {
            let salesData = try managedObjectContext.fetch(fetchRequest)
            return salesData.map { sale in
                DynaPriceModels.SaleRecord(
                    date: sale.date ?? Date(),
                    quantity: Int(sale.quantity),
                    hourPeriod: Int(sale.hourPeriod),
                    productEAN: sale.ean ?? "",
                    unitPrice: sale.unitPrice
                )
            }
        } catch {
            AppLogger.shared.error("Error fetching sales", category: .sales, error: error)
            return []
        }
    }
    
    func clearSalesData() throws {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Sale.fetchRequest()
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        try managedObjectContext.execute(batchDelete)
        try managedObjectContext.save()
        AppLogger.shared.info("Sales data cleared successfully", category: .database)
    }
}
