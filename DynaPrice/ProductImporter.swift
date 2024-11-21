import Foundation
import CoreData

class ProductImporter: ObservableObject {
    @Published var isImporting = false
    @Published var errorMessage: String?
    @Published var showAlert = false
    @Published var alertMessage = ""
    let viewContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }
    
    private func parsePrice(from string: String) throws -> Double {
        let cleanString = string
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "R$", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        
        guard let price = Double(cleanString) else {
            throw DynaPriceError.validationError("Invalid price format: \(string)")
        }
        
        return price
    }
    
    func importProducts(from csvString: String) {
        isImporting = true
        clearError()
        
        do {
            let cleanCSV = csvString.replacingOccurrences(of: "\r", with: "")
            let rows = cleanCSV.components(separatedBy: "\n")
            
            guard rows.count > 1 else {
                throw DynaPriceError.dataImportError("CSV file is empty or invalid")
            }
            
            try clearExistingProducts()
            
            var importedCount = 0
            for row in rows.dropFirst() where !row.isEmpty {
                let columns = row.components(separatedBy: ";")
                
                guard columns.count >= 12 else {
                    throw DynaPriceError.validationError("Invalid row format: insufficient columns")
                }
                
                try importProduct(columns: columns)
                importedCount += 1
                
                if importedCount % 50 == 0 {
                    try viewContext.save()
                    AppLogger.shared.info("Saved batch of \(importedCount) products", category: .database)
                }
            }
            
            try viewContext.save()
            alertMessage = "Successfully imported \(importedCount) products"
            AppLogger.shared.info("Import completed: \(importedCount) products", category: .database)
            
        } catch {
            handleError(error)
        }
        
        showAlert = true
        isImporting = false
    }
    
    private func clearExistingProducts() throws {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Product.fetchRequest()
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try viewContext.execute(batchDelete)
            try viewContext.save()
            viewContext.reset()
        } catch {
            throw DynaPriceError.databaseError("Failed to clear existing products: \(error.localizedDescription)")
        }
    }
    
    private func importProduct(columns: [String]) throws {
        let product = Product(context: viewContext)
        
        guard let itemCode = columns[safe: 0]?.trimmingCharacters(in: .whitespacesAndNewlines),
              let ean = columns[safe: 1]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !itemCode.isEmpty, !ean.isEmpty else {
            throw DynaPriceError.validationError("Missing required product identifiers")
        }
        
        product.itemCode = itemCode
        product.ean = ean
        product.name = columns[safe: 2]?.trimmingCharacters(in: .whitespacesAndNewlines)
        product.brand = columns[safe: 3]?.trimmingCharacters(in: .whitespacesAndNewlines)
        product.productDescription = columns[safe: 4]?.trimmingCharacters(in: .whitespacesAndNewlines)
        product.category = columns[safe: 8]?.trimmingCharacters(in: .whitespacesAndNewlines)
        product.department = columns[safe: 9]?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let priceString = columns[safe: 11] {
            product.currentPrice = try parsePrice(from: priceString)
        } else {
            throw DynaPriceError.validationError("Missing price for product: \(ean)")
        }
        
        product.lastUpdate = Date()
    }
    
    private func handleError(_ error: Error) {
        if let dynaError = error as? DynaPriceError {
            errorMessage = dynaError.localizedDescription
            alertMessage = dynaError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
            alertMessage = error.localizedDescription
        }
        ErrorHandler.shared.handle(error, category: .database)
    }
    
    private func clearError() {
        errorMessage = nil
        alertMessage = ""
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
