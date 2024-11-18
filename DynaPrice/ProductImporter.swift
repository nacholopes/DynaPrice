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
    
    private func parsePrice(from string: String) -> Double {
        // Remove newlines, currency symbol, and spaces
        var cleanString = string
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "R$", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "") // Remove non-breaking space
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Replace comma with dot for decimal
        cleanString = cleanString.replacingOccurrences(of: ",", with: ".")
        
        // Try to convert to Double
        if let price = Double(cleanString) {
            return price
        }
        
        print("Could not parse price from string: '\(string)', cleaned string: '\(cleanString)'")
        return 0.0
    }
    
    func importProducts(from csvString: String) {
        isImporting = true
        importError = nil
        
        // Clean the CSV string to remove any problematic characters
        let cleanCSV = csvString.replacingOccurrences(of: "\r", with: "")
        let rows = cleanCSV.components(separatedBy: "\n")
        var importedCount = 0
        
        do {
            // Clear existing products first
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Product.fetchRequest()
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try viewContext.execute(batchDeleteRequest)
            viewContext.reset() // Reset the context after batch delete
            
            // Process each row and create products
            for row in rows.dropFirst() where !row.isEmpty {
                let columns = row.components(separatedBy: ";")
                
                if columns.count >= 12 {
                    let product = Product(context: viewContext)
                    product.itemCode = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    product.ean = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    product.name = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
                    product.brand = columns[3].trimmingCharacters(in: .whitespacesAndNewlines)
                    product.productDescription = columns[4].trimmingCharacters(in: .whitespacesAndNewlines)
                    product.category = columns[8].trimmingCharacters(in: .whitespacesAndNewlines)
                    product.department = columns[9].trimmingCharacters(in: .whitespacesAndNewlines)
                    product.currentPrice = parsePrice(from: columns[11])
                    product.lastUpdate = Date()
                    
                    importedCount += 1
                    
                    // Save periodically to avoid memory issues
                    if importedCount % 50 == 0 {
                        try viewContext.save()
                    }
                }
            }
            
            // Final save
            try viewContext.save()
            
            alertMessage = "Successfully imported \(importedCount) products"
            showAlert = true
            
            // Print some sample data for verification
            let sampleRequest: NSFetchRequest<Product> = Product.fetchRequest()
            sampleRequest.fetchLimit = 5
            let samples = try viewContext.fetch(sampleRequest)
            for sample in samples {
                print("Imported: \(sample.name ?? "unknown") - R$ \(sample.currentPrice)")
            }
            
        } catch {
            alertMessage = "Error importing products: \(error.localizedDescription)"
            showAlert = true
            print("Import error: \(error)")
        }
        
        isImporting = false
    }
}
