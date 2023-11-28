//
//  File.swift
//  
//
//  Created by Yongun Lim on 2023/11/27.
//

import Foundation
import CoreData

public class UserRepository: SBUserStorage {
    private let coreStack: PersistenceManager
    private let context: NSManagedObjectContext
    
    required public init() {
        self.coreStack = CoreDataStack(configuration: PersistenceConfiguration(modelName: "User"))
        context = self.coreStack.viewContext
    }
    
    public func upsertUser(_ user: SBUser) {
        let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", user.userId)
        context.performAndWait {
            if let entity = try? self.context.fetch(fetchRequest).first {
                entity.nickname = user.nickname
                entity.profileURL = user.profileURL
            } else {
                // Create new user
                let newUser = UserEntity(context: self.context)
                newUser.userId = user.userId
                newUser.nickname = user.nickname
                newUser.profileURL = user.profileURL
            }
            try? self.context.save()
        }
    }
    
    public func getUsers() -> [SBUser] {
        var users = [SBUser]()
        let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        context.performAndWait {
            if let entities = try? self.context.fetch(fetchRequest) {
                users = entities.map { SBUser(userId: $0.userId, nickname: $0.nickname) }
            }
        }
        return users
    }
    
    public func getUsers(for nickname: String) -> [SBUser] {
        var users = [SBUser]()
        let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        context.performAndWait {
            fetchRequest.predicate = NSPredicate(format: "nickname == %@", nickname)
            if let entities = try? self.context.fetch(fetchRequest) {
                users = entities.map { SBUser(userId: $0.userId, nickname: $0.nickname) }
            }
        }
        return users
    }
    
    public func getUser(for userId: String) -> (SBUser)? {
        var user: SBUser?
        let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        context.performAndWait {
            if let entity = try? self.context.fetch(fetchRequest).first {
                user = entity.transforms()
            }
        }
        return user
    }
    
    public func removeAll() -> Bool {
        let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        do {
            let entities = try self.context.fetch(fetchRequest)
            entities.forEach { item in
                self.context.delete(item)
            }
        } catch {
            return false
        }
        return true
    }
    
}
