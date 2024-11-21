import Foundation
import CoreData

class SalesAnalyzer: ObservableObject {
    private let viewContext: NSManagedObjectContext
    private let salesManager: SalesDataManager
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        self.salesManager = SalesDataManager(context: context)
    }
    
    func analyzeSalesForProduct(_ product: Product, timeWindow: String) -> PriceSuggestion? {
        guard let ean = product.ean else { return nil }
        
        // Convert time window to hours
        let hoursToAnalyze: Int
        switch timeWindow {
        case "Hour": hoursToAnalyze = 1
        case "Day": hoursToAnalyze = 24
        case "Week": hoursToAnalyze = 24 * 7
        case "Month": hoursToAnalyze = 24 * 30
        default: hoursToAnalyze = 24
        }
        
        // Get current sales and baseline data
        let currentSales = salesManager.fetchRecentSales(for: ean, timeWindow: hoursToAnalyze)
        guard let baseline = fetchBaseline(for: ean, hour: getCurrentHourPeriod()) else {
            print("No baseline found for product: \(ean)")
            return nil
        }
        
        print("\n🔍 Analyzing sales for product \(ean) over \(hoursToAnalyze) hours")
        print("Found \(currentSales.count) current sales records")
        
        // Calculate current metrics vs baseline
        let metrics = compareWithBaseline(sales: currentSales, baseline: baseline)
        
        // Evaluate triggers with baseline comparison
        let triggers = fetchActiveTriggers()
        for trigger in triggers {
            if let suggestion = evaluateTriggerWithBaseline(trigger, metrics: metrics, for: product) {
                return suggestion
            }
        }
        
        return nil
    }
    
    private func getCurrentHourPeriod() -> Int16 {
        let hour = Calendar.current.component(.hour, from: Date())
        // Convert 24-hour format to your 1-15 period format
        return Int16((hour - 7) / 1) + 1 // Assuming periods start at 7AM
    }
    
    private func fetchBaseline(for ean: String, hour: Int16) -> HourlyBaseline? {
        let request = NSFetchRequest<HourlyBaseline>(entityName: "HourlyBaseline")
        request.predicate = NSPredicate(format: "ean == %@ AND hourPeriod == %d", ean, hour)
        request.fetchLimit = 1
        
        do {
            return try viewContext.fetch(request).first
        } catch {
            print("Error fetching baseline: \(error)")
            return nil
        }
    }
    
    private struct BaselineMetrics {
        var currentVolume: Int
        var expectedVolume: Double
        var percentageDeviation: Double
        var isWeekendEffect: Bool
        var isPaydayEffect: Bool
        var seasonalTrend: Double
    }
    
    private func compareWithBaseline(sales: [DynaPriceModels.SaleRecord], baseline: HourlyBaseline) -> BaselineMetrics {
        // Calculate current volume
        let currentVolume = sales.reduce(0) { $0 + $1.quantity }
        
        // Get current date components
        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now) - 1 // 0-based index
        let day = calendar.component(.day, from: now) - 1 // 0-based index
        let dayOfWeek = calendar.component(.weekday, from: now) - 1 // 0-based index
        
        // Extract baseline patterns
        let monthlyPattern = (baseline.monthlyMeans as? [Double])?[month] ?? 0
        let dailyPattern = (baseline.dailyMeans as? [Double])?[day] ?? 0
        let dowPattern = (baseline.dowMeans as? [Double])?[dayOfWeek] ?? 0
        
        // Calculate expected volume considering all patterns
        let expectedBase = baseline.totalMeanQuantity
        let expectedVolume = expectedBase *
            (monthlyPattern / baseline.totalMeanQuantity) *
            (dailyPattern / baseline.totalMeanQuantity) *
            (dowPattern / baseline.totalMeanQuantity)
        
        // Calculate deviation
        let percentageDeviation = expectedVolume > 0 ?
            ((Double(currentVolume) - expectedVolume) / expectedVolume) * 100 : 0
        
        // Detect patterns
        let isWeekendEffect = calendar.isDateInWeekend(now)
        let isPaydayEffect = [1, 5, 15].contains(day + 1)
        
        // Calculate seasonal trend
        let seasonalTrend = monthlyPattern / baseline.totalMeanQuantity
        
        print("\nBaseline Comparison:")
        print("Current Volume: \(currentVolume)")
        print("Expected Volume: \(expectedVolume)")
        print("Deviation: \(String(format: "%.1f", percentageDeviation))%")
        print("Weekend Effect: \(isWeekendEffect)")
        print("Payday Effect: \(isPaydayEffect)")
        print("Seasonal Trend: \(String(format: "%.2f", seasonalTrend))")
        
        return BaselineMetrics(
            currentVolume: currentVolume,
            expectedVolume: expectedVolume,
            percentageDeviation: percentageDeviation,
            isWeekendEffect: isWeekendEffect,
            isPaydayEffect: isPaydayEffect,
            seasonalTrend: seasonalTrend
        )
    }
    
    private func evaluateTriggerWithBaseline(_ trigger: PriceTrigger, metrics: BaselineMetrics, for product: Product) -> PriceSuggestion? {
        guard trigger.active else { return nil }
        
        let threshold = trigger.percentageThreshold
        let direction = trigger.direction ?? "increase"
        
        print("\nTrigger Evaluation:")
        print("Deviation: \(metrics.percentageDeviation)%")
        print("Threshold: \(threshold)%")
        print("Direction: \(direction)")
        
        // Consider baseline metrics in evaluation
        var adjustedDeviation = metrics.percentageDeviation
        
        // Adjust for known patterns
        if metrics.isWeekendEffect { adjustedDeviation *= 0.8 } // Reduce sensitivity on weekends
        if metrics.isPaydayEffect { adjustedDeviation *= 0.7 } // Reduce sensitivity on paydays
        
        // Consider seasonal trends
        if metrics.seasonalTrend > 1.2 { // High season
            adjustedDeviation *= 0.9 // Less sensitive to increases
        } else if metrics.seasonalTrend < 0.8 { // Low season
            adjustedDeviation *= 1.2 // More sensitive to decreases
        }
        
        let changeExceedsThreshold = direction == "increase" ?
            adjustedDeviation >= threshold :
            adjustedDeviation <= -threshold
        
        if changeExceedsThreshold {
            print("🎯 Adjusted threshold exceeded!")
            return createSuggestion(
                for: product,
                trigger: trigger,
                percentageChange: direction == "increase" ? trigger.priceChangePercentage : -trigger.priceChangePercentage,
                reason: generateReason(metrics: metrics, direction: direction)
            )
        }
        
        print("❌ Threshold not exceeded")
        return nil
    }
    
    private func generateReason(metrics: BaselineMetrics, direction: String) -> String {
        var reasons: [String] = []
        
        reasons.append("Sales \(direction)d by \(String(format: "%.1f", abs(metrics.percentageDeviation)))%")
        reasons.append("Expected: \(String(format: "%.1f", metrics.expectedVolume))")
        reasons.append("Actual: \(metrics.currentVolume)")
        
        if metrics.isWeekendEffect {
            reasons.append("Weekend effect considered")
        }
        if metrics.isPaydayEffect {
            reasons.append("Payday effect considered")
        }
        if metrics.seasonalTrend != 1.0 {
            reasons.append("Seasonal trend: \(String(format: "%.1f", metrics.seasonalTrend))x")
        }
        
        return reasons.joined(separator: ". ")
    }
    
    private func fetchActiveTriggers() -> [PriceTrigger] {
        let request = NSFetchRequest<PriceTrigger>(entityName: "PriceTrigger")
        request.predicate = NSPredicate(format: "active == YES")
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching triggers: \(error)")
            return []
        }
    }
    
    private func createSuggestion(for product: Product, trigger: PriceTrigger, percentageChange: Double, reason: String) -> PriceSuggestion {
        let suggestion = PriceSuggestion(context: viewContext)
        suggestion.id = UUID()
        suggestion.product = product
        suggestion.trigger = trigger
        suggestion.currentPrice = product.currentPrice
        suggestion.suggestedPrice = product.currentPrice * (1 + (percentageChange / 100))
        suggestion.reason = reason
        suggestion.percentageChange = percentageChange
        suggestion.timestamp = Date()
        suggestion.status = "pending"
        suggestion.createdAt = Date()
        suggestion.productCurrentPrice = product.currentPrice
        
        do {
            try viewContext.save()
            print("💾 Saved new price suggestion")
        } catch {
            print("❌ Error saving suggestion: \(error)")
        }
        
        return suggestion
    }
}
