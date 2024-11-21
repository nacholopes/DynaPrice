//
//  Sale+CoreDataProperties.swift
//  DynaPrice
//
//  Created by Eduardo Lopes on 20/11/24.
//
//

import Foundation
import CoreData


extension Sale {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Sale> {
        return NSFetchRequest<Sale>(entityName: "Sale")
    }

    @NSManaged public var date: Date?
    @NSManaged public var day: Int16
    @NSManaged public var dayOfWeek: Int16
    @NSManaged public var ean: String?
    @NSManaged public var hourPeriod: Int16
    @NSManaged public var id: UUID?
    @NSManaged public var month: Int16
    @NSManaged public var quantity: Int16
    @NSManaged public var totalAmount: Double
    @NSManaged public var unitPrice: Double
    @NSManaged public var product: Product?

}

extension Sale : Identifiable {

}
