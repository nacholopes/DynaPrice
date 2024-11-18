import SwiftUI
import CoreData

class POSSimulatorViewModel: ObservableObject {
    @Published private var simulator: POSSimulatorService
    
    init(context: NSManagedObjectContext) {
        self.simulator = POSSimulatorService(context: context)
    }
    
    // MARK: - Public Properties
    var isRunning: Bool { simulator.isRunning }
    var speedMultiplier: Int { simulator.speedMultiplier }
    var totalSalesGenerated: Int { simulator.totalSalesGenerated }
    var simulationTime: Date { simulator.simulationTime }
    
    // MARK: - Pattern Controls
    var enableWeekendBoost: Bool {
        get { simulator.enableWeekendBoost }
        set { simulator.enableWeekendBoost = newValue }
    }
    
    var enableLunchRush: Bool {
        get { simulator.enableLunchRush }
        set { simulator.enableLunchRush = newValue }
    }
    
    var enablePaydayEffect: Bool {
        get { simulator.enablePaydayEffect }
        set { simulator.enablePaydayEffect = newValue }
    }
    
    // MARK: - Control Methods
    func toggleSimulation() {
        if simulator.isRunning {
            simulator.stopSimulation()
        } else {
            simulator.startSimulation()
        }
    }
    
    func resetSimulation() {
        simulator.resetSimulation()
    }
    
    func setSpeed(_ multiplier: Int) {
        guard multiplier != simulator.speedMultiplier else { return }
        
        // Restart simulation with new speed if running
        let wasRunning = simulator.isRunning
        if wasRunning {
            simulator.stopSimulation()
        }
        
        simulator.speedMultiplier = multiplier
        
        if wasRunning {
            simulator.startSimulation()
        }
    }
}
