//
//  PriceSuggestion+CoreDataProperties.swift
//  DynaPrice
//
//  Created by Eduardo Lopes on 20/11/24.
//
//

import Foundation
import CoreData


extension PriceSuggestion {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PriceSuggestion> {
        return NSFetchRequest<PriceSuggestion>(entityName: "PriceSuggestion")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var currentPrice: Double
    @NSManaged public var id: UUID?
    @NSManaged public var percentageChange: Double
    @NSManaged public var productCurrentPrice: Double
    @NSManaged public var reason: String?
    @NSManaged public var status: String?
    @NSManaged public var suggestedPrice: Double
    @NSManaged public var timestamp: Date?
    @NSManaged public var product: Product?
    @NSManaged public var trigger: PriceTrigger?

}

extension PriceSuggestion : Identifiable {

}
