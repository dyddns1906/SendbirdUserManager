//
//  UserEntity+CoreDataClass.swift
//  SendbirdUserManager
//
//  Created by Yongun Lim on 2023/11/27.
//
//

import Foundation
import CoreData

@objc(UserEntity)
public class UserEntity: NSManagedObject {

}

extension UserEntity {
    func transforms() -> SBUser {
        return SBUser(userId: self.userId, nickname: self.nickname, profileURL: self.profileURL)
    }
}
