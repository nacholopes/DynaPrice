//
//  PriceTrigger+CoreDataProperties.swift
//  DynaPrice
//
//  Created by Eduardo Lopes on 20/11/24.
//
//

import Foundation
import CoreData


extension PriceTrigger {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PriceTrigger> {
        return NSFetchRequest<PriceTrigger>(entityName: "PriceTrigger")
    }

    @NSManaged public var action: String?
    @NSManaged public var active: Bool
    @NSManaged public var competitors: String?
    @NSManaged public var condition: String?
    @NSManaged public var daysOfWeek: String?
    @NSManaged public var direction: String?
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var percentageThreshold: Double
    @NSManaged public var priceChangePercentage: Double
    @NSManaged public var timeWindow: Int16
    @NSManaged public var timeWindowEnd: Int16
    @NSManaged public var timeWindowStart: Int16
    @NSManaged public var triggerType: String?
    @NSManaged public var suggestions: PriceSuggestion?

}

extension PriceTrigger : Identifiable {

}
