//
//  HourlyBaseline+CoreDataProperties.swift
//  DynaPrice
//
//  Created by Eduardo Lopes on 20/11/24.
//
//

import Foundation
import CoreData


extension HourlyBaseline {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<HourlyBaseline> {
        return NSFetchRequest<HourlyBaseline>(entityName: "HourlyBaseline")
    }

    @NSManaged public var dailyMeans: NSArray?
    @NSManaged public var dailyMedians: NSArray?
    @NSManaged public var dowMeans: NSArray?
    @NSManaged public var dowMedians: NSArray?
    @NSManaged public var ean: String?
    @NSManaged public var hourPeriod: Int16
    @NSManaged public var monthlyMeans: NSArray?
    @NSManaged public var monthlyMedians: NSArray?
    @NSManaged public var totalMeanQuantity: Double
    @NSManaged public var totalMedianQuantity: Double
    @NSManaged public var product: Product?

}

extension HourlyBaseline : Identifiable {

}
