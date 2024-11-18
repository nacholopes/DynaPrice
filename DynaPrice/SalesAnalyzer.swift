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
        case "Hour":
            hoursToAnalyze = 1
        case "Day":
            hoursToAnalyze = 24
        case "Week":
            hoursToAnalyze = 24 * 7
        case "Month":
            hoursToAnalyze = 24 * 30
        default:
            hoursToAnalyze = 24
        }
        
        // Fetch active triggers
        let triggers = fetchActiveTriggers()
        if triggers.isEmpty {
            print("No active triggers found")
            return nil
        }
        
        // Get sales records for the product
        let sales = salesManager.fetchRecentSales(for: ean, timeWindow: hoursToAnalyze)
        if sales.isEmpty {
            print("No sales found for product: \(ean)")
            return nil
        }
        
        print("\n🔍 Analyzing sales for product \(ean) over \(hoursToAnalyze) hours")
        print("Found \(sales.count) sales records")
        
        // Sort sales by date, newest first
        let sortedSales = sales.sorted { $0.date > $1.date }
        print("\nRecent sales history:")
        for sale in sortedSales.prefix(10) {
            print("📊 \(sale.date): \(sale.quantity) units (Hour: \(sale.hourPeriod))")
        }
        
        // Calculate metrics based on time window
        let metrics = calculateSalesMetrics(sales: sortedSales, windowInHours: hoursToAnalyze)
        print("\n📈 Sales metrics over \(hoursToAnalyze) hours:")
        print("Current period volume: \(metrics.currentVolume)")
        print("Previous period volume: \(metrics.previousVolume)")
        print("Percentage change: \(String(format: "%.1f", metrics.percentageChange))%")
        
        // Evaluate triggers
        for trigger in triggers {
            if let suggestion = evaluateTrigger(trigger, metrics: metrics, for: product) {
                return suggestion
            }
        }
        
        return nil
    }
    
    private func calculateSalesMetrics(sales: [DynaPriceModels.SaleRecord], windowInHours: Int) -> (percentageChange: Double, currentVolume: Int, previousVolume: Int) {
        guard let mostRecentDate = sales.first?.date else {
            return (percentageChange: 0, currentVolume: 0, previousVolume: 0)
        }
        
        // Calculate period durations based on window
        let periodDuration = windowInHours / 2 // Split the window in half
        
        // Group sales by period
        let currentPeriodSales = sales.filter { sale in
            let hoursDifference = Calendar.current.dateComponents([.hour], from: sale.date, to: mostRecentDate).hour ?? 0
            return hoursDifference <= periodDuration
        }
        
        let previousPeriodSales = sales.filter { sale in
            let hoursDifference = Calendar.current.dateComponents([.hour], from: sale.date, to: mostRecentDate).hour ?? 0
            return hoursDifference > periodDuration && hoursDifference <= (periodDuration * 2)
        }
        
        // Calculate volumes
        let currentVolume = currentPeriodSales.reduce(0) { $0 + $1.quantity }
        let previousVolume = previousPeriodSales.reduce(0) { $0 + $1.quantity }
        
        print("\nDetailed volume analysis:")
        print("Current period (\(periodDuration) hours):")
        currentPeriodSales.forEach { sale in
            print("  - \(sale.date): \(sale.quantity) units")
        }
        print("Previous period (\(periodDuration) hours):")
        previousPeriodSales.forEach { sale in
            print("  - \(sale.date): \(sale.quantity) units")
        }
        
        // Calculate percentage change
        var percentageChange = 0.0
        if previousVolume > 0 {
            percentageChange = ((Double(currentVolume) - Double(previousVolume)) / Double(previousVolume)) * 100
        } else if currentVolume > 0 {
            // Only mark as significant increase if current volume is substantial
            percentageChange = currentVolume >= 5 ? 100 : 0
        }
        
        return (percentageChange: percentageChange, currentVolume: currentVolume, previousVolume: previousVolume)
    }
    
    private func evaluateTrigger(_ trigger: PriceTrigger, metrics: (percentageChange: Double, currentVolume: Int, previousVolume: Int), for product: Product) -> PriceSuggestion? {
            guard trigger.active else { return nil }
            
            let threshold = trigger.percentageThreshold
            let direction = trigger.direction ?? "increase"
            
            print("\nTrigger Evaluation:")
            print("Current volume: \(metrics.currentVolume)")
            print("Previous volume: \(metrics.previousVolume)")
            print("Percentage change: \(metrics.percentageChange)%")
            print("Threshold: \(threshold)%")
            print("Direction: \(direction)")
            
            // Check if metrics match trigger conditions
            let changeExceedsThreshold = direction == "increase"
                ? metrics.percentageChange >= threshold
                : metrics.percentageChange <= -threshold
                
            if changeExceedsThreshold {
                print("🎯 Threshold exceeded!")
                return createSuggestion(
                    for: product,
                    trigger: trigger,  // Pass the trigger
                    percentageChange: direction == "increase" ? trigger.priceChangePercentage : -trigger.priceChangePercentage,
                    reason: "Sales \(direction)d by \(String(format: "%.1f", abs(metrics.percentageChange)))% (Current: \(metrics.currentVolume), Previous: \(metrics.previousVolume))"
                )
            }
            
            print("❌ Threshold not exceeded")
            return nil
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
            suggestion.trigger = trigger  // Store reference to trigger
            suggestion.currentPrice = product.currentPrice
            suggestion.suggestedPrice = product.currentPrice * (1 + (percentageChange / 100))
            suggestion.reason = reason
            suggestion.percentageChange = percentageChange
            suggestion.timestamp = Date()
            suggestion.status = "pending"
            suggestion.createdAt = Date()
            suggestion.productCurrentPrice = product.currentPrice
            
            // Try to save immediately
            do {
                try viewContext.save()
                print("💾 Saved new price suggestion")
            } catch {
                print("❌ Error saving suggestion: \(error)")
            }
            
            return suggestion
        }
}
