import Foundation
import CoreData

class TriggerManager: ObservableObject {
    @Published var triggers: [PriceTrigger] = []
    private let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        fetchTriggers()
    }

    func fetchTriggers() {
        let request = NSFetchRequest<PriceTrigger>(entityName: "PriceTrigger")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PriceTrigger.name, ascending: true)]
        
        do {
            triggers = try viewContext.fetch(request)
            print("Fetched \(triggers.count) triggers")
        } catch {
            print("Error fetching triggers: \(error)")
        }
    }
    
    func deleteTrigger(_ trigger: PriceTrigger) {
        viewContext.delete(trigger)
        try? viewContext.save()
        fetchTriggers()
    }

    // Original sales volume trigger
    func addNewTrigger(name: String,
                      triggerType: String,
                      active: Bool,
                      percentageThreshold: Double,
                      timeWindow: Int16,
                      priceChangePercentage: Double,
                      direction: String) {
        let newTrigger = PriceTrigger(context: viewContext)
        newTrigger.name = name
        newTrigger.triggerType = triggerType
        newTrigger.active = active
        newTrigger.percentageThreshold = percentageThreshold
        newTrigger.timeWindow = timeWindow
        newTrigger.priceChangePercentage = priceChangePercentage
        newTrigger.direction = direction
        
        print("Creating sales volume trigger: \(name)")
        
        do {
            try viewContext.save()
            print("Trigger saved successfully")
            fetchTriggers()
        } catch {
            print("Error saving trigger: \(error)")
        }
    }
    
    // New time-based trigger
    func addNewTimeTrigger(name: String,
                          startHour: Int,
                          endHour: Int,
                          daysOfWeek: Set<Int>,
                          priceChangePercentage: Double) {
        let newTrigger = PriceTrigger(context: viewContext)
        newTrigger.name = name
        newTrigger.triggerType = DynaPriceModels.TriggerType.timeBasedRule.rawValue
        newTrigger.active = true
        newTrigger.timeWindowStart = Int16(startHour)
        newTrigger.timeWindowEnd = Int16(endHour)
        newTrigger.daysOfWeek = daysOfWeek.map(String.init).joined(separator: ",")
        newTrigger.priceChangePercentage = priceChangePercentage
        
        print("Creating time-based trigger: \(name)")
        print("Hours: \(startHour)-\(endHour), Days: \(daysOfWeek)")
        
        do {
            try viewContext.save()
            print("Time trigger saved successfully")
            fetchTriggers()
        } catch {
            print("Error saving time trigger: \(error)")
        }
    }
    
    // New competitor price trigger
    func addNewCompetitorTrigger(name: String,
                                competitorNames: [String],
                                thresholdPercentage: Double,
                                priceChangePercentage: Double) {
        let newTrigger = PriceTrigger(context: viewContext)
        newTrigger.name = name
        newTrigger.triggerType = DynaPriceModels.TriggerType.competitorPrice.rawValue
        newTrigger.active = true
        newTrigger.competitors = competitorNames.joined(separator: ",")
        newTrigger.percentageThreshold = thresholdPercentage
        newTrigger.priceChangePercentage = priceChangePercentage
        
        print("Creating competitor trigger: \(name)")
        print("Competitors: \(competitorNames)")
        
        do {
            try viewContext.save()
            print("Competitor trigger saved successfully")
            fetchTriggers()
        } catch {
            print("Error saving competitor trigger: \(error)")
        }
    }
    
    // Helper function to update existing trigger
    func updateTrigger(_ trigger: PriceTrigger) {
        do {
            try viewContext.save()
            print("Trigger updated successfully")
            fetchTriggers()
        } catch {
            print("Error updating trigger: \(error)")
        }
    }
}
