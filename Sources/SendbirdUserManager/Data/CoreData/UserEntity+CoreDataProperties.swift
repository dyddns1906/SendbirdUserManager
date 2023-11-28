//
//  UserEntity+CoreDataProperties.swift
//  SendbirdUserManager
//
//  Created by Yongun Lim on 2023/11/27.
//
//

import Foundation
import CoreData


extension UserEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserEntity> {
        return NSFetchRequest<UserEntity>(entityName: "UserEntity")
    }

    @NSManaged public var userId: String
    @NSManaged public var profileURL: String?
    @NSManaged public var nickname: String?

}
