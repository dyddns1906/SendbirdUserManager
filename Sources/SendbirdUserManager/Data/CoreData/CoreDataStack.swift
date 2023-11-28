//
//  CoreDataStack.swift
//  
//
//  Created by Yongun Lim on 2023/11/27.
//

import Foundation
import CoreData

public class CoreDataStack: PersistenceManager {
    
    public var viewContext: NSManagedObjectContext { container.viewContext }
    
    public var container: PersistentContainer
    
    required public init(configuration: PersistenceConfiguration) {
        let model = CoreDataStack.model(for: configuration.modelName)

        self.container = .init(name: configuration.modelName,
                               managedObjectModel: model)

        self.container.persistentStoreDescriptions.first?.configuration = configuration.configuration
        self.container.persistentStoreDescriptions.first?.type = NSInMemoryStoreType
        self.container.loadPersistentStores(completionHandler: { (desc, err) in
            if let err = err {
                fatalError("CoreDataStack: \(desc): \(err)")
            }
        })
    }
    
    static func model(for name: String) -> NSManagedObjectModel {
        guard let url = Bundle.module.url(forResource: name, withExtension: "momd") else { fatalError("URL이 올바르지 않음: \(name)") }

        guard let model = NSManagedObjectModel(contentsOf: url) else { fatalError("모델 찾을 수 없음: \(url)") }

        return model
    }
}

