//
//  Product+CoreDataProperties.swift
//  DynaPrice
//
//  Created by Eduardo Lopes on 20/11/24.
//
//

import Foundation
import CoreData


extension Product {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Product> {
        return NSFetchRequest<Product>(entityName: "Product")
    }

    @NSManaged public var brand: String?
    @NSManaged public var category: String?
    @NSManaged public var currentPrice: Double
    @NSManaged public var department: String?
    @NSManaged public var ean: String?
    @NSManaged public var itemCode: String?
    @NSManaged public var lastUpdate: Date?
    @NSManaged public var name: String?
    @NSManaged public var productDescription: String?
    @NSManaged public var templateId: Int32
    @NSManaged public var baseline: HourlyBaseline?
    @NSManaged public var suggestions: PriceSuggestion?
    @NSManaged public var sales: Sale?

}

extension Product : Identifiable {

}
