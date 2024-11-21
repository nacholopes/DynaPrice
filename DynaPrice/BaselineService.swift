import Foundation
import CoreData
import Combine

class BaselineService: ObservableObject {
    private let viewContext: NSManagedObjectContext
    @Published var latestDeviation: DeviationResult?
    @Published var errorMessage: String?
    
    struct DeviationResult: Equatable {
        let weightedDeviation: Double
        let deviations: [String: Double]
        let patternsDetected: [String]
        let confidence: Double
        
        static func == (lhs: DeviationResult, rhs: DeviationResult) -> Bool {
            lhs.weightedDeviation == rhs.weightedDeviation &&
            lhs.deviations == rhs.deviations &&
            lhs.patternsDetected == rhs.patternsDetected &&
            lhs.confidence == rhs.confidence
        }
    }
    
    private let weights: [String: Double] = [
        "hour": 0.4,
        "dow": 0.3,
        "day": 0.2,
        "month": 0.1
    ]
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }
    
    func analyzeSale(_ sale: Sale) -> DeviationResult? {
        guard let ean = sale.ean else {
            handleError(.validationError("Sale has no EAN code"))
            return nil
        }
        
        guard let baseline = fetchBaseline(for: ean, hourPeriod: sale.hourPeriod) else {
            handleError(.baselineError("No baseline found for product \(ean)"))
            return nil
        }
        
        do {
            let deviations = try calculateDeviations(sale: sale, baseline: baseline)
            let patterns = detectPatterns(sale: sale, deviations: deviations)
            let weightedDeviation = calculateWeightedDeviation(deviations)
            let confidence = calculateConfidence(baseline: baseline)
            
            return DeviationResult(
                weightedDeviation: weightedDeviation,
                deviations: deviations,
                patternsDetected: patterns,
                confidence: confidence
            )
        } catch {
            handleError(error)
            return nil
        }
    }
    
    private func fetchBaseline(for ean: String, hourPeriod: Int16) -> HourlyBaseline? {
        do {
            let request = NSFetchRequest<HourlyBaseline>(entityName: "HourlyBaseline")
            request.predicate = NSPredicate(format: "ean == %@ AND hourPeriod == %d", ean, hourPeriod)
            request.fetchLimit = 1
            return try viewContext.fetch(request).first
        } catch {
            handleError(.databaseError("Failed to fetch baseline: \(error.localizedDescription)"))
            return nil
        }
    }
    
    private func calculateDeviations(sale: Sale, baseline: HourlyBaseline) throws -> [String: Double] {
        var deviations: [String: Double] = [:]
        
        guard let monthlyMeans = baseline.monthlyMeans as? [Double],
              let dailyMeans = baseline.dailyMeans as? [Double],
              let dowMeans = baseline.dowMeans as? [Double] else {
            throw DynaPriceError.baselineError("Invalid baseline data format")
        }
        
        // Hour deviation
        deviations["hour"] = calculatePercentageDeviation(
            actual: Double(sale.quantity),
            expected: baseline.totalMeanQuantity
        )
        
        // Day of week deviation
        if sale.dayOfWeek > 0 && sale.dayOfWeek <= 7 {
            deviations["dow"] = calculatePercentageDeviation(
                actual: Double(sale.quantity),
                expected: dowMeans[Int(sale.dayOfWeek) - 1]
            )
        }
        
        if sale.month > 0 && sale.month <= 12 {
            deviations["month"] = calculatePercentageDeviation(
                actual: Double(sale.quantity),
                expected: monthlyMeans[Int(sale.month) - 1]
            )
        }
        
        if sale.day > 0 && sale.day <= 31 {
            deviations["day"] = calculatePercentageDeviation(
                actual: Double(sale.quantity),
                expected: dailyMeans[Int(sale.day) - 1]
            )
        }
        
        return deviations
    }
    
    private func calculatePercentageDeviation(actual: Double, expected: Double) -> Double {
        guard expected != 0 else { return 0 }
        return (actual - expected) / expected
    }
    
    private func detectPatterns(sale: Sale, deviations: [String: Double]) -> [String] {
        var patterns: [String] = []
        
        if [6, 7].contains(sale.dayOfWeek) && (deviations["dow"] ?? 0) > 0.15 {
            patterns.append("weekend_effect")
        }
        
        if (11...14).contains(sale.hourPeriod) && (deviations["hour"] ?? 0) > 0.25 {
            patterns.append("lunch_rush")
        }
        
        if [1, 15].contains(sale.day) && (deviations["day"] ?? 0) > 0.2 {
            patterns.append("payday_effect")
        }
        
        return patterns
    }
    
    private func calculateWeightedDeviation(_ deviations: [String: Double]) -> Double {
        deviations.reduce(0.0) { sum, item in
            sum + (item.value * (weights[item.key] ?? 0))
        }
    }
    
    private func calculateConfidence(baseline: HourlyBaseline) -> Double {
        let hasMonthlyData = (baseline.monthlyMeans as? [Double])?.isEmpty == false
        let hasDailyData = (baseline.dailyMeans as? [Double])?.isEmpty == false
        let hasDOWData = (baseline.dowMeans as? [Double])?.isEmpty == false
        
        let confidenceFactors = [hasMonthlyData, hasDailyData, hasDOWData]
        return Double(confidenceFactors.filter { $0 }.count) / Double(confidenceFactors.count)
    }
    
    private func handleError(_ error: Error) {
        if let dynaError = error as? DynaPriceError {
            errorMessage = dynaError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }
        ErrorHandler.shared.handle(error, category: .baseline)
    }
    
    private func handleError(_ dynaError: DynaPriceError) {
        errorMessage = dynaError.localizedDescription
        ErrorHandler.shared.handle(dynaError, category: .baseline)
    }
}
