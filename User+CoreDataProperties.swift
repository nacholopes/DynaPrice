//
//  User+CoreDataProperties.swift
//  DynaPrice
//
//  Created by Eduardo Lopes on 20/11/24.
//
//

import Foundation
import CoreData


extension User {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<User> {
        return NSFetchRequest<User>(entityName: "User")
    }

    @NSManaged public var email: String?
    @NSManaged public var id: UUID?
    @NSManaged public var isActive: Bool
    @NSManaged public var lastLogin: Date?
    @NSManaged public var passwordHash: String?
    @NSManaged public var role: String?

}

extension User : Identifiable {

}
