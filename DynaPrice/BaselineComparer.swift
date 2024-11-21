import Foundation
import CoreData

class BaselineComparer: ObservableObject {
    private let viewContext: NSManagedObjectContext
    private let weights: [String: Double] = [
        "hour": 0.4,
        "dow": 0.3,
        "day": 0.2,
        "month": 0.1
    ]
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }
    
    struct DeviationResult {
        let weightedDeviation: Double
        let deviations: [String: Double]
        let patternsDetected: [String]
    }
    
    func calculateDeviation(for sale: Sale, baseline: HourlyBaseline) -> DeviationResult? {
        guard let monthlyMeans = baseline.monthlyMeans as? [Double],
              let dailyMeans = baseline.dailyMeans as? [Double],
              let dowMeans = baseline.dowMeans as? [Double] else {
            return nil
        }
        
        // Calculate individual deviations
        let deviations: [String: Double] = [
            "hour": calculatePercentageDeviation(actual: Double(sale.quantity), expected: baseline.totalMeanQuantity),
            "dow": calculatePercentageDeviation(actual: Double(sale.quantity), expected: dowMeans[Int(sale.dayOfWeek) - 1]),
            "day": calculatePercentageDeviation(actual: Double(sale.quantity), expected: dailyMeans[Int(sale.day) - 1]),
            "month": calculatePercentageDeviation(actual: Double(sale.quantity), expected: monthlyMeans[Int(sale.month) - 1])
        ]
        
        // Calculate weighted deviation
        let weightedDeviation = deviations.reduce(0.0) { sum, item in
            sum + (item.value * (weights[item.key] ?? 0))
        }
        
        // Detect patterns
        let patterns = detectPatterns(sale: sale, deviations: deviations)
        
        return DeviationResult(
            weightedDeviation: weightedDeviation,
            deviations: deviations,
            patternsDetected: patterns
        )
    }
    
    private func calculatePercentageDeviation(actual: Double, expected: Double) -> Double {
        guard expected != 0 else { return 0 }
        return (actual - expected) / expected
    }
    
    private func detectPatterns(sale: Sale, deviations: [String: Double]) -> [String] {
        var patterns: [String] = []
        
        // Payday effect
        if [1, 5, 10, 15, 20, 25, 30].contains(Int(sale.day)) &&
           (deviations["day"] ?? 0) > 0.2 {
            patterns.append("payday_effect")
        }
        
        // Weekend effect
        if [6, 7].contains(Int(sale.dayOfWeek)) &&
           (deviations["dow"] ?? 0) > 0.15 {
            patterns.append("weekend_effect")
        }
        
        // Lunch rush
        if (5...8).contains(Int(sale.hourPeriod)) &&
           (deviations["hour"] ?? 0) > 0.25 {
            patterns.append("lunch_rush")
        }
        
        return patterns
    }
    
    func fetchBaseline(for ean: String, hourPeriod: Int16) -> HourlyBaseline? {
        let request = NSFetchRequest<HourlyBaseline>(entityName: "HourlyBaseline")
        request.predicate = NSPredicate(format: "ean == %@ AND hourPeriod == %d", ean, hourPeriod)
        request.fetchLimit = 1
        
        return try? viewContext.fetch(request).first
    }
}
