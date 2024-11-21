import Foundation
import CoreData
import Combine

class POSSimulatorService: ObservableObject {
    @Published var isRunning = false {
        didSet {
            if isRunning {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }
    @Published var speedMultiplier = 1
    @Published var simulationTime = Date()
    
    // Boost Properties
    private var activeTrigger: PriceTrigger?
    private var boostStartTime: Date?
    private var boostConfig: BoostConfiguration?
    
    // Private properties
    private(set) var viewContext: NSManagedObjectContext?
    private var timerCancellable: AnyCancellable?
    private var products: [Product] = []
    private let backgroundContext: NSManagedObjectContext
    
    private struct BoostConfiguration {
        let direction: String
        let threshold: Double
        let timeWindow: Int16
        let targetProducts: [Product]
        let salesIncreaseFactor: Double
        
        init?(from trigger: PriceTrigger, products: [Product]) {
            guard let direction = trigger.direction else { return nil }
            
            self.direction = direction
            self.threshold = trigger.percentageThreshold
            self.timeWindow = trigger.timeWindow
            self.targetProducts = products
            
            // Calculate boost factor based on trigger type and parameters
            if direction == "increase" {
                self.salesIncreaseFactor = 1 + (trigger.percentageThreshold / 100.0)
            } else {
                self.salesIncreaseFactor = 1 - (trigger.percentageThreshold / 100.0)
            }
        }
    }
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        self.backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        self.backgroundContext.parent = context
        loadProducts()
    }
    
    func activateBoost(with trigger: PriceTrigger) {
        guard trigger.active else { return }
        
        // Initialize boost configuration
        boostConfig = BoostConfiguration(from: trigger, products: products)
        activeTrigger = trigger
        boostStartTime = simulationTime
        
        AppLogger.shared.info("Sales boost activated with trigger: \(trigger.name ?? "Unknown")", category: .simulation)
    }
    
    func deactivateBoost() {
        boostConfig = nil
        activeTrigger = nil
        boostStartTime = nil
        AppLogger.shared.info("Sales boost deactivated", category: .simulation)
    }
    
    func startSimulation() {
        guard !isRunning else { return }
        guard !products.isEmpty else {
            AppLogger.shared.error("Cannot start simulation - no products loaded", category: .simulation, error: nil)
            return
        }
        
        AppLogger.shared.info("Starting simulation with \(products.count) products", category: .simulation)
        isRunning = true
    }
    
    func stopSimulation() {
        guard isRunning else { return }
        isRunning = false
        AppLogger.shared.info("Simulation stopped", category: .simulation)
    }
    
    func setSpeed(_ multiplier: Int) {
        speedMultiplier = multiplier
        if isRunning {
            startTimer() // Restart timer with new speed
        }
    }
    
    func resetSimulation() {
        if isRunning {
            stopSimulation()
        }
        
        simulationTime = Date()
        clearExistingSales()
        AppLogger.shared.info("Simulation reset complete", category: .simulation)
    }
    
    private func startTimer() {
        stopTimer() // Ensure any existing timer is cancelled
        
        let interval = 1.0 / Double(speedMultiplier)
        timerCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.generateSales()
            }
    }
    
    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }
    
    private func loadProducts() {
        let request = NSFetchRequest<Product>(entityName: "Product")
        request.predicate = NSPredicate(format: "ean != nil AND ean != '' AND currentPrice > 0")
        
        do {
            products = try viewContext?.fetch(request) ?? []
        } catch {
            AppLogger.shared.error("Failed to load products", category: .simulation, error: error)
            products = []
        }
    }
    
    private func clearExistingSales() {
        backgroundContext.performAndWait {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Sale.fetchRequest()
            let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDelete.resultType = .resultTypeObjectIDs
            
            do {
                let result = try backgroundContext.execute(batchDelete) as? NSBatchDeleteResult
                let changes: [AnyHashable: Any] = [
                    NSDeletedObjectsKey: result?.result as? [NSManagedObjectID] ?? []
                ]
                
                DispatchQueue.main.async { [weak self] in
                    guard let viewContext = self?.viewContext else { return }
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
                }
                
                try backgroundContext.save()
                AppLogger.shared.info("Sales data cleared", category: .database)
            } catch {
                AppLogger.shared.error("Failed to clear sales data", category: .simulation, error: error)
            }
        }
    }
    
    private func generateSales() {
        guard isRunning else { return }
        
        simulationTime = Calendar.current.date(byAdding: .minute, value: speedMultiplier, to: simulationTime) ?? simulationTime
        
        let validProducts = products.filter { $0.ean?.isEmpty == false }
        guard !validProducts.isEmpty else { return }
        
        // Split products into boost and non-boost groups
        let (boostedProducts, normalProducts) = splitProducts(validProducts)
        
        // Generate sales for boosted products
        if !boostedProducts.isEmpty {
            generateBoostedSales(for: boostedProducts)
        }
        
        // Generate normal sales for remaining products
        if !normalProducts.isEmpty {
            generateNormalSales(for: normalProducts)
        }
    }
    
    private func splitProducts(_ products: [Product]) -> (boosted: [Product], normal: [Product]) {
        guard let boostConfig = boostConfig else {
            return ([], products)
        }
        
        let boostedProducts = products.filter { product in
            boostConfig.targetProducts.contains { $0.ean == product.ean }
        }
        
        let normalProducts = products.filter { product in
            !boostedProducts.contains { $0.ean == product.ean }
        }
        
        return (boostedProducts, normalProducts)
    }
    
    private func generateBoostedSales(for products: [Product]) {
        guard let boostConfig = boostConfig else { return }
        
        let baseProbability = calculateSalesProbability()
        let boostedProbability = min(baseProbability * boostConfig.salesIncreaseFactor, 1.0)
        
        let eligibleProducts = products.shuffled().prefix(5)
        
        backgroundContext.perform { [weak self] in
            guard let self = self, self.isRunning else { return }
            
            for product in eligibleProducts {
                if Double.random(in: 0...1) < boostedProbability {
                    do {
                        // Generate multiple sales for boosted products
                        let numberOfSales = Int.random(in: 2...5)
                        for _ in 0..<numberOfSales {
                            if let sale = try self.createSale(for: product, isBoostSale: true) {
                                try self.backgroundContext.save()
                                
                                DispatchQueue.main.async {
                                    NotificationCenter.default.post(
                                        name: Notification.Name("com.dynaprice.newSaleGenerated"),
                                        object: sale
                                    )
                                }
                            }
                        }
                    } catch {
                        AppLogger.shared.error("Failed to generate boosted sale", category: .simulation, error: error)
                    }
                }
            }
        }
    }
    
    private func generateNormalSales(for products: [Product]) {
        let probability = calculateSalesProbability()
        let eligibleProducts = products.shuffled().prefix(3)
        
        backgroundContext.perform { [weak self] in
            guard let self = self, self.isRunning else { return }
            
            for product in eligibleProducts {
                if Double.random(in: 0...1) < probability {
                    do {
                        if let sale = try self.createSale(for: product, isBoostSale: false) {
                            try self.backgroundContext.save()
                            
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(
                                    name: Notification.Name("com.dynaprice.newSaleGenerated"),
                                    object: sale
                                )
                            }
                        }
                    } catch {
                        AppLogger.shared.error("Failed to generate normal sale", category: .simulation, error: error)
                    }
                }
            }
        }
    }
    
    private func createSale(for product: Product, isBoostSale: Bool) throws -> Sale? {
        guard let productInContext = backgroundContext.object(with: product.objectID) as? Product,
              let ean = productInContext.ean,
              !ean.isEmpty else {
            return nil
        }
        
        let sale = Sale(context: backgroundContext)
        sale.id = UUID()
        sale.date = simulationTime
        sale.ean = ean
        sale.quantity = Int16(isBoostSale ? Int.random(in: 3...8) : Int.random(in: 1...5))
        sale.unitPrice = productInContext.currentPrice
        sale.totalAmount = Double(sale.quantity) * sale.unitPrice
        sale.hourPeriod = Int16(Calendar.current.component(.hour, from: simulationTime))
        sale.month = Int16(Calendar.current.component(.month, from: simulationTime))
        sale.day = Int16(Calendar.current.component(.day, from: simulationTime))
        sale.dayOfWeek = Int16(Calendar.current.component(.weekday, from: simulationTime))
        sale.product = productInContext
        
        return sale
    }
    
    private func calculateSalesProbability() -> Double {
        let probability = 0.3
        let _ = Calendar.current.component(.hour, from: simulationTime)  // Using _ since unused
        let _ = Calendar.current.component(.weekday, from: simulationTime)
        let _ = Calendar.current.component(.day, from: simulationTime)
            
//        if enableWeekendBoost && (dayOfWeek == 1 || dayOfWeek == 7) {
//            probability *= 1.5
//        }
//        
//        if enableLunchRush && (hour >= 11 && hour <= 14) {
//            probability *= 1.8
//        }
//        
//        if enablePaydayEffect && (dayOfMonth == 5 || dayOfMonth == 20) {
//            probability *= 1.4
//        }
        
        return min(probability, 1.0)
    }
}
