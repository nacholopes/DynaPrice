import Foundation
import CoreData
import Combine

class POSSimulatorService: ObservableObject {
    @Published var isRunning = false
    @Published var speedMultiplier: Int = 1
    @Published var simulationTime: Date = Date()
    @Published var totalSalesGenerated: Int = 0
    
    // Pattern Flags
    @Published var enableWeekendBoost = false
    @Published var enableLunchRush = false
    @Published var enablePaydayEffect = false
    
    private let viewContext: NSManagedObjectContext
    private var timer: Timer?
    private var simulationTimer: AnyCancellable?
    private let salesManager: SalesDataManager
    
    // Keep track of products for simulation
    private var products: [Product] = []
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        self.salesManager = SalesDataManager(context: context)
        loadProducts()
    }
    
    private func loadProducts() {
        let request = NSFetchRequest<Product>(entityName: "Product")
        do {
            products = try viewContext.fetch(request)
            print("Loaded \(products.count) products for simulation")
        } catch {
            print("Error loading products: \(error)")
        }
    }
    
    func startSimulation() {
        guard !isRunning else { return }
        isRunning = true
        
        // Calculate timer interval based on speed multiplier
        let baseInterval = 1.0 // 1 second represents 1 minute in simulation
        let interval = baseInterval / Double(speedMultiplier)
        
        simulationTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.generateSales()
            }
        
        print("🎮 Simulation started at \(speedMultiplier)x speed")
    }
    
    func stopSimulation() {
        isRunning = false
        simulationTimer?.cancel()
        print("🛑 Simulation stopped")
    }
    
    func resetSimulation() {
        stopSimulation()
        totalSalesGenerated = 0
        simulationTime = Date()
        
        // Clear existing sales
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Sale.fetchRequest()
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try viewContext.execute(batchDelete)
            try viewContext.save()
            print("🔄 Simulation reset complete")
        } catch {
            print("Error resetting sales: \(error)")
        }
    }
    
    private func generateSales() {
        // Advance simulation time
        simulationTime = Calendar.current.date(byAdding: .minute, value: speedMultiplier, to: simulationTime) ?? simulationTime
        
        // Get current hour and day of week in simulation
        let hour = Calendar.current.component(.hour, from: simulationTime)
        let dayOfWeek = Calendar.current.component(.weekday, from: simulationTime)
        let dayOfMonth = Calendar.current.component(.day, from: simulationTime)
        
        // Base probability of a sale occurring
        var salesProbability = 0.3
        
        // Apply pattern modifiers
        if enableWeekendBoost && (dayOfWeek == 1 || dayOfWeek == 7) {
            salesProbability *= 1.5
        }
        
        if enableLunchRush && (hour >= 11 && hour <= 14) {
            salesProbability *= 1.8
        }
        
        if enablePaydayEffect && (dayOfMonth == 5 || dayOfMonth == 20) {
            salesProbability *= 1.4
        }
        
        // Generate sales for random products
        for product in products {
            if Double.random(in: 0...1) < salesProbability {
                createSale(for: product, at: simulationTime)
            }
        }
    }
    
    private func createSale(for product: Product, at date: Date) {
        guard let ean = product.ean else { return }
        
        let sale = Sale(context: viewContext)
        sale.id = UUID()
        sale.date = date
        sale.ean = ean
        sale.quantity = Int16(Int.random(in: 1...5))
        sale.unitPrice = product.currentPrice
        sale.totalAmount = Double(sale.quantity) * sale.unitPrice
        sale.hourPeriod = Int16(Calendar.current.component(.hour, from: date))
        sale.month = Int16(Calendar.current.component(.month, from: date))
        sale.day = Int16(Calendar.current.component(.day, from: date))
        sale.dayOfWeek = Int16(Calendar.current.component(.weekday, from: date))
        
        do {
            try viewContext.save()
            totalSalesGenerated += 1
            print("💰 Sale generated: \(product.name ?? "Unknown") - Qty: \(sale.quantity)")
        } catch {
            print("Error saving sale: \(error)")
            viewContext.rollback()
        }
    }
}
