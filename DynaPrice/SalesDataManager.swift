import Foundation
import CoreData

class SalesDataManager: ObservableObject {
    private let managedObjectContext: NSManagedObjectContext
    @Published var isImporting = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    init(context: NSManagedObjectContext) {
        self.managedObjectContext = context
    }
    
    func fetchRecentSales(for ean: String, timeWindow: Int = 24) -> [DynaPriceModels.SaleRecord] {
        let fetchRequest = NSFetchRequest<Sale>(entityName: "Sale")
        
        // Calculate the date threshold
        let calendar = Calendar.current
        let now = Date()
        guard let thresholdDate = calendar.date(byAdding: .hour, value: -timeWindow, to: now) else {
            print("Could not calculate threshold date")
            return []
        }
        
        // Set up fetch criteria
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "ean == %@", ean),
            NSPredicate(format: "date >= %@", thresholdDate as NSDate)
        ])
        
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \Sale.date, ascending: false)
        ]
        
        do {
            let salesData = try managedObjectContext.fetch(fetchRequest)
            print("Found \(salesData.count) sales for EAN \(ean) in last \(timeWindow) hours")
            
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
            print("Error fetching sales: \(error)")
            return []
        }
    }
    
    func importSalesData(from csvString: String) {
        isImporting = true
        print("Starting sales import...")
        
        let cleanCSV = csvString.replacingOccurrences(of: "\r", with: "")
        let rows = cleanCSV.components(separatedBy: "\n")
        var importedCount = 0
        
        print("Found \(rows.count) rows in CSV")
        
        // Clear existing sales
        clearExistingSales()
        
        for row in rows.dropFirst() where !row.isEmpty {
            let columns = row.components(separatedBy: ",")
            
            if columns.count >= 9 {
                let sale = Sale(context: managedObjectContext)
                sale.id = UUID()
                sale.date = parseDate(columns[0])
                sale.month = Int16(columns[1]) ?? 0
                sale.day = Int16(columns[2]) ?? 0
                sale.dayOfWeek = Int16(columns[3]) ?? 0
                sale.hourPeriod = Int16(columns[4]) ?? 0
                sale.ean = columns[5]
                sale.quantity = Int16(columns[6]) ?? 0
                sale.unitPrice = Double(columns[7]) ?? 0.0
                sale.totalAmount = Double(columns[8]) ?? 0.0
                
                importedCount += 1
                
                if importedCount % 100 == 0 {
                    print("Imported \(importedCount) sales records...")
                    try? managedObjectContext.save()
                }
            }
        }
        
        do {
            try managedObjectContext.save()
            print("Successfully imported \(importedCount) sales records")
            
            // Verify some imported data
            let fetchRequest = NSFetchRequest<Sale>(entityName: "Sale")
            fetchRequest.fetchLimit = 5
            let samples = try managedObjectContext.fetch(fetchRequest)
            print("Sample sales data:")
            for sale in samples {
                print("Sale - Date: \(sale.date ?? Date()), EAN: \(sale.ean ?? ""), Qty: \(sale.quantity)")
            }
            
            // Group by EAN and show totals
            let groupedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Sale")
            let groupByEAN = NSExpressionDescription()
            groupByEAN.name = "ean"
            groupByEAN.expression = NSExpression(forKeyPath: "ean")
            groupByEAN.expressionResultType = .stringAttributeType
            
            let countDesc = NSExpressionDescription()
            countDesc.name = "count"
            countDesc.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "ean")])
            countDesc.expressionResultType = .integer64AttributeType
            
            groupedRequest.propertiesToFetch = [groupByEAN, countDesc]
            groupedRequest.propertiesToGroupBy = ["ean"]
            groupedRequest.resultType = .dictionaryResultType
            
            if let results = try managedObjectContext.fetch(groupedRequest) as? [[String: Any]] {
                print("\nSales by product:")
                for result in results {
                    if let ean = result["ean"] as? String,
                       let count = result["count"] as? Int {
                        print("EAN: \(ean), Total sales: \(count)")
                    }
                }
            }
            
            alertMessage = "Successfully imported \(importedCount) sales records"
        } catch {
            print("Error saving sales: \(error)")
            alertMessage = "Error importing sales: \(error.localizedDescription)"
        }
        
        showAlert = true
        isImporting = false
    }
    
    private func parseDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString) ?? Date()
    }
    
    private func clearExistingSales() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Sale.fetchRequest()
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try managedObjectContext.execute(batchDeleteRequest)
            try managedObjectContext.save()
            print("Cleared existing sales data")
        } catch {
            print("Error clearing sales: \(error)")
        }
    }
}
