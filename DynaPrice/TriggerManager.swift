import Foundation
import CoreData

class TriggerManager: ObservableObject {
    @Published var triggers: [PriceTrigger] = []
    @Published var errorMessage: String?
    private let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        fetchTriggers()
    }

    func fetchTriggers() {
        do {
            let request = NSFetchRequest<PriceTrigger>(entityName: "PriceTrigger")
            request.sortDescriptors = [NSSortDescriptor(keyPath: \PriceTrigger.name, ascending: true)]
            triggers = try viewContext.fetch(request)
            AppLogger.shared.info("Fetched \(triggers.count) triggers", category: .trigger)
        } catch {
            handleError(.triggerError("Failed to fetch triggers: \(error.localizedDescription)"))
        }
    }
    
    func deleteTrigger(_ trigger: PriceTrigger) {
        do {
            viewContext.delete(trigger)
            try viewContext.save()
            fetchTriggers()
        } catch {
            handleError(.triggerError("Failed to delete trigger: \(error.localizedDescription)"))
        }
    }

    func addNewTrigger(name: String,
                      triggerType: String,
                      active: Bool,
                      percentageThreshold: Double,
                      timeWindow: Int16,
                      priceChangePercentage: Double,
                      direction: String) {
        do {
            guard !name.isEmpty else {
                throw DynaPriceError.validationError("Trigger name cannot be empty")
            }
            
            let newTrigger = PriceTrigger(context: viewContext)
            newTrigger.name = name
            newTrigger.triggerType = triggerType
            newTrigger.active = active
            newTrigger.percentageThreshold = percentageThreshold
            newTrigger.timeWindow = timeWindow
            newTrigger.priceChangePercentage = priceChangePercentage
            newTrigger.direction = direction
            
            try viewContext.save()
            AppLogger.shared.info("Created sales volume trigger: \(name)", category: .trigger)
            fetchTriggers()
            
        } catch {
            handleError(error)
        }
    }
    
    func addNewTimeTrigger(name: String,
                          startHour: Int,
                          endHour: Int,
                          daysOfWeek: Set<Int>,
                          priceChangePercentage: Double) {
        do {
            guard !name.isEmpty else {
                throw DynaPriceError.validationError("Trigger name cannot be empty")
            }
            
            guard startHour >= 0 && startHour < 24 && endHour >= 0 && endHour < 24 else {
                throw DynaPriceError.validationError("Invalid hour range")
            }
            
            guard !daysOfWeek.isEmpty else {
                throw DynaPriceError.validationError("Must select at least one day")
            }
            
            let newTrigger = PriceTrigger(context: viewContext)
            newTrigger.name = name
            newTrigger.triggerType = DynaPriceModels.TriggerType.timeBasedRule.rawValue
            newTrigger.active = true
            newTrigger.timeWindowStart = Int16(startHour)
            newTrigger.timeWindowEnd = Int16(endHour)
            newTrigger.daysOfWeek = daysOfWeek.map(String.init).joined(separator: ",")
            newTrigger.priceChangePercentage = priceChangePercentage
            
            try viewContext.save()
            AppLogger.shared.info("Created time-based trigger: \(name)", category: .trigger)
            fetchTriggers()
            
        } catch {
            handleError(error)
        }
    }
    
    func addNewCompetitorTrigger(name: String,
                                competitorNames: [String],
                                thresholdPercentage: Double,
                                priceChangePercentage: Double) {
        do {
            guard !name.isEmpty else {
                throw DynaPriceError.validationError("Trigger name cannot be empty")
            }
            
            guard !competitorNames.isEmpty else {
                throw DynaPriceError.validationError("Must specify at least one competitor")
            }
            
            let newTrigger = PriceTrigger(context: viewContext)
            newTrigger.name = name
            newTrigger.triggerType = "competitorPrice"
            newTrigger.active = true
            newTrigger.competitors = competitorNames.joined(separator: ",")
            newTrigger.percentageThreshold = thresholdPercentage
            newTrigger.priceChangePercentage = priceChangePercentage
            
            try viewContext.save()
            AppLogger.shared.info("Created competitor trigger: \(name)", category: .trigger)
            fetchTriggers()
            
        } catch {
            handleError(error)
        }
    }
    
    func updateTrigger(_ trigger: PriceTrigger) {
        do {
            try viewContext.save()
            AppLogger.shared.info("Updated trigger: \(trigger.name ?? "")", category: .trigger)
            fetchTriggers()
        } catch {
            handleError(.triggerError("Failed to update trigger: \(error.localizedDescription)"))
        }
    }
    
    private func handleError(_ error: Error) {
        if let dynaError = error as? DynaPriceError {
            errorMessage = dynaError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }
        ErrorHandler.shared.handle(error, category: .trigger)
    }
    
    private func handleError(_ dynaError: DynaPriceError) {
        errorMessage = dynaError.localizedDescription
        ErrorHandler.shared.handle(dynaError, category: .trigger)
    }
}
