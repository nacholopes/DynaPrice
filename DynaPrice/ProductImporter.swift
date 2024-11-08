import Foundation
import CoreData
import SwiftUI

class ProductImporter: ObservableObject {
    @Published var isImporting = false
    @Published var importError: String?
    @Published var showAlert = false
    @Published var alertMessage = ""
    let viewContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }
    
    func importProducts(from csvString: String) {
        isImporting = true
        importError = nil
        
        let rows = csvString.components(separatedBy: "\n")
        let headerRow = rows[0].components(separatedBy: ";")
        
        // Clear existing products
        clearExistingProducts()
        
        var importedCount = 0
        
        for row in rows.dropFirst() where !row.isEmpty {
            let columns = row.components(separatedBy: ";")
            if columns.count >= headerRow.count {
                let product = Product(context: viewContext)
                product.itemCode = columns[0]
                product.ean = columns[1]
                product.name = columns[2]
                product.brand = columns[3]
                
                // Convert price string (e.g., "R$ 21,99") to Double
                if let priceStr = columns[10].replacingOccurrences(of: "R$ ", with: "")
                    .replacingOccurrences(of: ",", with: ".")
                    .trimmingCharacters(in: .whitespacesAndNewlines) as String?,
                   let price = Double(priceStr) {
                    product.currentPrice = price
                }
                
                product.department = columns[9]
                product.category = columns[8]
                product.lastUpdate = Date()
                product.templateId = 1 // Default template ID
                importedCount += 1
            }
        }
        
        do {
            try viewContext.save()
            alertMessage = "Successfully imported \(importedCount) products"
            showAlert = true
            isImporting = false
        } catch {
            alertMessage = "Error importing products: \(error.localizedDescription)"
            showAlert = true
            isImporting = false
        }
    }
    
    private func clearExistingProducts() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Product.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try viewContext.execute(deleteRequest)
            try viewContext.save()
        } catch {
            print("Error clearing products: \(error)")
        }
    }
}
