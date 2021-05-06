//
//  EncryptionManager.swift
//  CoreDataCipher
//
//  Created by Niroshan Maheswaran on 06.05.21.
//

import Foundation
import CoreData
import CryptoSwift

protocol CoreDataManager {
    
    /// Main managed object context for peforming task on main thread.
    var mainManagedObjectContext: NSManagedObjectContext { get }
    
    /// Saves changes from child managed object contexts to parent managed object context
    /// and finally pushes changes to persisten store.
    func saveChanges(completion: @escaping (Bool) -> Void)
    
    /// Creates an private child managed object context.
    func privateChildManagedObjectContext() -> NSManagedObjectContext
}

class CoreDataManagerImpl: NSObject, CoreDataManager {
    
    // MARK: - Public properties
    
    public typealias CoreDataManagerCompletion = () -> ()
    public private(set) lazy var mainManagedObjectContext: NSManagedObjectContext = {
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        
        managedObjectContext.parent = self.privateManagedObjectContext
        
        return managedObjectContext
    }()
    
    // MARK: - Private properties
    
    private let modelName: String = "DataModel"
    private let completion: CoreDataManagerCompletion
    private let encryptionManager: EncryptionManager
    
    private lazy var managedObjectModel: NSManagedObjectModel = {
        guard let modelURL = Bundle.main.url(forResource: self.modelName, withExtension: "momd") else {
            fatalError("Unable to find data model.")
        }
        
        guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Unable to load data model.")
        }
        
        return managedObjectModel
    }()
    
    private lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        return NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
    }()
    
    private lazy var privateManagedObjectContext: NSManagedObjectContext = {
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        
        managedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator
        
        return managedObjectContext
    }()
    
    private lazy var encryptionKey: [UInt8] = {
        encryptionManager.getEncryptionKey()
    }()
    
    private lazy var initializationVector: [UInt8] = {
        encryptionManager.getIV()
    }()
    
    // MARK: - Public methods
    
    /// Initializer
    /// - Parameters:
    ///   - completion: Completion handler.
    public init(
        encryptionManager: EncryptionManager,
        completion: @escaping CoreDataManagerCompletion
    ) {
        self.completion = completion
        self.encryptionManager = encryptionManager
        
        super.init()
        
        // Set up value transformers for encryption
        do {
            try setTransformers()
        } catch {
            fatalError(error.localizedDescription)
        }
        
        setupCoreDataStack()
    }
    
    public func saveChanges(completion: @escaping (Bool) -> Void) {
        mainManagedObjectContext.performAndWait {
            do {
                if self.mainManagedObjectContext.hasChanges {
                    try self.mainManagedObjectContext.save()
                }
            } catch {
                print("Unable to save changes of main managed object context.")
                print("\(error), \(error.localizedDescription)")
                completion(false)
            }
        }
        
        privateManagedObjectContext.perform {
            do {
                if self.privateManagedObjectContext.hasChanges {
                    try self.privateManagedObjectContext.save()
                    completion(true)
                }
            } catch {
                print("Unable to save changes of private managed object context.")
                print("\(error), \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    public func privateChildManagedObjectContext() -> NSManagedObjectContext {
        let managedObjectConext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectConext.parent = mainManagedObjectContext
        return managedObjectConext
    }
}

// MARK: - Private methods

private extension CoreDataManagerImpl {
    
    func setupCoreDataStack() {
        guard let persistentStoreCoordinator = mainManagedObjectContext.persistentStoreCoordinator else {
            fatalError("Unable to set up core data stack.")
        }
        
        DispatchQueue.global().async {
            /// Add persistent store
            self.addPersistentStore(to: persistentStoreCoordinator)
            
            /// Invoke completion on main queue
            DispatchQueue.main.async {
                self.completion()
            }
        }
    }
    
    func addPersistentStore(to persistentStoreCoordinator: NSPersistentStoreCoordinator) {
        /// Helpers
        let fileManager = FileManager.default
        let storeName = "\(self.modelName).sqlite"
        
        /// URL documents directory
        let documentsDirectoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        /// URL persistent store
        let persistentStoreURL = documentsDirectoryURL.appendingPathComponent(storeName)
        
        do {
            let options = [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true
            ]
            
            try persistentStoreCoordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: persistentStoreURL,
                options: options
            )
        } catch {
            fatalError("Unable to add persistent store.")
        }
    }
    
    /// Set any value transformers that will be used by CoreData.
    /// It will automatically create and supply an AES-256 cipher.
    func setTransformers() throws {
        
        // typealias to be able to iterate over generic type CryptoValueTransformer
        typealias NamedTransformer = ValueTransformer & ValueTransformerNamed
        
        // Create AES cipher in ECB mode
        var aesCBCCipher: Cipher?
        do {
            aesCBCCipher = try AES(key: encryptionKey, blockMode: CBC(iv: initializationVector))
        } catch {
            // since we can't use the database when there is no cipher, there is nothing
            // we can do about it. here we could ask a flow controller to display a selection
            // to let the user decide what to do (e.g. rebuild DB from scratch).
            fatalError(error.localizedDescription)
        }
        
        // Create transformers for types used in the data model
        guard let cbcCipher = aesCBCCipher else { fatalError("There is no encryption key!") }
        let transformers: [NamedTransformer] = [
            
            // Primitive types
            CryptoValueTransformer<String>(cipher: cbcCipher),
            CryptoValueTransformer<Date>(cipher: cbcCipher),
            CryptoValueTransformer<Int>(cipher: cbcCipher),
            CryptoValueTransformer<Float>(cipher: cbcCipher),
            CryptoValueTransformer<Bool>(cipher: cbcCipher),
            CryptoValueTransformer<UUID>(cipher: cbcCipher),
        ]
        
        // set transformers to be used
        transformers.forEach {
            print("Setting value transformer for \"\($0.name.rawValue)\"")
            ValueTransformer.setValueTransformer($0, forName: $0.name)
        }
    }
}
