import Foundation
import CoreData

class BaselineImporter: ObservableObject {
    @Published var isImporting = false
    @Published var errorMessage: String?
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    private let viewContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }
    
    private func clearExistingBaselines() throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "HourlyBaseline")
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try viewContext.execute(batchDelete)
            try viewContext.save()
            AppLogger.shared.info("Cleared existing baselines", category: .database)
        } catch {
            throw DynaPriceError.databaseError("Failed to clear baselines: \(error.localizedDescription)")
        }
    }
    
    func importBaselines(from csvString: String) {
        isImporting = true
        clearError()
        
        do {
            guard let entityDescription = NSEntityDescription.entity(forEntityName: "HourlyBaseline", in: viewContext) else {
                throw DynaPriceError.databaseError("Failed to get entity description for HourlyBaseline")
            }
            
            let cleanCSV = csvString.replacingOccurrences(of: "\r", with: "")
            let rows = cleanCSV.components(separatedBy: "\n")
            
            guard rows.count > 1 else {
                throw DynaPriceError.dataImportError("CSV file is empty or invalid")
            }
            
            try clearExistingBaselines()
            
            var importedCount = 0
            for row in rows.dropFirst() where !row.isEmpty {
                let columns = row.components(separatedBy: ",")
                
                guard columns.count >= 102 else {
                    throw DynaPriceError.validationError("Invalid row format: expected 102 columns, got \(columns.count)")
                }
                
                try importBaseline(columns: columns, entityDescription: entityDescription)
                importedCount += 1
                
                if importedCount % 50 == 0 {
                    try viewContext.save()
                    AppLogger.shared.info("Saved batch of \(importedCount) baselines", category: .database)
                }
            }
            
            try viewContext.save()
            alertMessage = "Successfully imported \(importedCount) baselines"
            AppLogger.shared.info("Import completed: \(importedCount) baselines", category: .database)
            
        } catch {
            handleError(error)
        }
        
        showAlert = true
        isImporting = false
    }
    
    private func importBaseline(columns: [String], entityDescription: NSEntityDescription) throws {
        let baseline = HourlyBaseline(entity: entityDescription, insertInto: viewContext)
        
        guard let ean = columns[safe: 0],
              let hourPeriod = Int16(columns[safe: 1] ?? ""),
              let totalMedian = Double(columns[safe: 2] ?? ""),
              let totalMean = Double(columns[safe: 3] ?? "") else {
            throw DynaPriceError.validationError("Invalid baseline data format")
        }
        
        baseline.ean = ean
        baseline.hourPeriod = hourPeriod
        baseline.totalMedianQuantity = totalMedian
        baseline.totalMeanQuantity = totalMean
        
        baseline.monthlyMedians = try extractDoubleArray(from: columns, start: 4, count: 12)
        baseline.monthlyMeans = try extractDoubleArray(from: columns, start: 16, count: 12)
        baseline.dailyMedians = try extractDoubleArray(from: columns, start: 28, count: 31)
        baseline.dailyMeans = try extractDoubleArray(from: columns, start: 59, count: 31)
        baseline.dowMedians = try extractDoubleArray(from: columns, start: 90, count: 7)
        baseline.dowMeans = try extractDoubleArray(from: columns, start: 97, count: 7)
    }
    
    private func extractDoubleArray(from columns: [String], start: Int, count: Int) throws -> NSArray {
        let end = min(start + count, columns.count)
        let values = columns[start..<end].compactMap { Double($0) }
        
        guard values.count == count else {
            throw DynaPriceError.validationError("Invalid array data: expected \(count) values, got \(values.count)")
        }
        
        return values as NSArray
    }
    
    private func handleError(_ error: Error) {
        if let dynaError = error as? DynaPriceError {
            errorMessage = dynaError.localizedDescription
            alertMessage = dynaError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
            alertMessage = error.localizedDescription
        }
        AppLogger.shared.error(errorMessage ?? "Unknown error", category: .database, error: error)
        ErrorHandler.shared.handle(error, category: .database)
    }
    
    private func clearError() {
        errorMessage = nil
        alertMessage = ""
    }
}
