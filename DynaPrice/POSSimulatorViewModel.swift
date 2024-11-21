import SwiftUI
import CoreData
import Combine

class POSSimulatorViewModel: ObservableObject {
    // Published Properties
    @Published private(set) var isRunning = false
    @Published private(set) var speedMultiplier: Int = 1
    @Published private(set) var simulationTime: Date = Date()
    @Published private(set) var recentSales: [Sale] = []
    @Published var activeTrigger: PriceTrigger?
    @Published var isBoostActive = false
    
    private let maxRecentSales = 5
    private let simulator: POSSimulatorService
    private var cancellables = Set<AnyCancellable>()
    
    init(context: NSManagedObjectContext) {
        self.simulator = POSSimulatorService(context: context)
        setupBindings()
    }
    
    private func setupBindings() {
        simulator.$isRunning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRunning)
        
        simulator.$speedMultiplier
            .receive(on: DispatchQueue.main)
            .assign(to: &$speedMultiplier)
        
        simulator.$simulationTime
            .receive(on: DispatchQueue.main)
            .assign(to: &$simulationTime)
        
        NotificationCenter.default.publisher(for: Notification.Name("com.dynaprice.newSaleGenerated"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let sale = notification.object as? Sale {
                    self?.addRecentSale(sale)
                }
            }
            .store(in: &cancellables)
    }
    
    private func addRecentSale(_ sale: Sale) {
        recentSales.insert(sale, at: 0)
        if recentSales.count > maxRecentSales {
            recentSales.removeLast()
        }
    }
    
    // Existing methods remain unchanged
    func toggleSimulation() {
        if isRunning {
            simulator.stopSimulation()
        } else {
            simulator.startSimulation()
        }
    }
    
    func setSpeed(_ multiplier: Int) {
        guard multiplier != speedMultiplier else { return }
        simulator.setSpeed(multiplier)
    }
    
    func resetSimulation() {
        simulator.resetSimulation()
        deactivateBoost()
    }
    
    func activateBoost(trigger: PriceTrigger) {
        guard !isBoostActive else { return }
        activeTrigger = trigger
        isBoostActive = true
        simulator.activateBoost(with: trigger)
    }
    
    func deactivateBoost() {
        guard isBoostActive else { return }
        activeTrigger = nil
        isBoostActive = false
        simulator.deactivateBoost()
    }
}
