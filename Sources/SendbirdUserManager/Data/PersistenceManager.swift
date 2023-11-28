//
//  PersistenceManager.swift
//  
//
//  Created by Yongun Lim on 2023/11/27.
//

import Foundation
import CoreData

public protocol PersistenceManager {
    var viewContext: NSManagedObjectContext { get }
    var container: PersistentContainer { get }
    init(configuration: PersistenceConfiguration)
}

public struct PersistenceConfiguration {
    public let modelName: String
    public let configuration: String?
    
    public init(
        modelName: String,
        configuration: String? = nil
    ) {

        self.modelName = modelName
        self.configuration = configuration
    }
}

open class PersistentContainer: NSPersistentContainer {
//    override open class func defaultDirectoryURL() -> URL {
//        return super.defaultDirectoryURL()
//            .appendingPathComponent("CoreDataModel")
//            .appendingPathComponent("Local")
//    }
}
