//
//  TasksRepository.swift
//  CoreDataCipher
//
//  Created by Niroshan Maheswaran on 06.05.21.
//

import UIKit
import CoreData

public typealias Success = (Bool) -> Void

protocol TasksRepository {
    
    /// Creates new task.
    /// - Parameters:
    ///   - task: Task.
    func createTask(
        _ task: String,
        completion: @escaping Success
    )
    
    /// Returns all tasks.
    func readAllTasks() -> [Task]
    
    /// Returns task with predicate.
    /// - Parameter predicate: Search predicate.
    func readTask(with predicate: NSPredicate) -> Task?
    
    /// Updates task.
    /// - Parameters:
    ///   - identifier: Identifier of task which needs to be updated.
    ///   - title: Title of new task.
    ///   - completion: Completion handler.
    func updateTaskWith(
        identifier: UUID,
        title: String,
        completion: @escaping Success
    )
    
    /// Deletes task.
    /// - Parameters:
    ///   - identifier: Identifier of user.
    func delete(
        with identifier: UUID,
        completion: @escaping Success
    )
    
    /// Deletes all tasks.
    /// - Parameter completion: Completion handler.
    func deleteAll(completion: @escaping Success)
}

class TaskRepositoryImpl: TasksRepository {
    
    // MARK: - Private properties
    
    private let manager: CoreDataManager
    
    // MARK: - Public methods
    
    init(manager: CoreDataManager) {
        self.manager = manager
    }
    
    func createTask(
        _ task: String,
        completion: @escaping Success
    ) {
        let context = manager.mainManagedObjectContext
        let taskEntity = Task(context: context)
        
        let newTaskId = UUID()
        let creationDate = Date()
        
        taskEntity.taskId = newTaskId
        taskEntity.title = task
        taskEntity.creationDate = creationDate
        
        manager.saveChanges(completion: completion)
    }
    
    func readAllTasks() -> [Task] {
        let context = manager.mainManagedObjectContext
        var tasks: [Task] = []
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: Task.self))
        
        do {
            let result = try context.fetch(fetchRequest)
            tasks = result as? [Task] ?? []
        } catch {
            print("There is currently no users available.")
        }
        
        return tasks
    }
    
    func readTask(with predicate: NSPredicate) -> Task? {
        let context = manager.mainManagedObjectContext
        var searchingTask: Task?
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: Task.self))
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = predicate
        
        do {
            let result = try context.fetch(fetchRequest)
            searchingTask = (result as? [Task])?.first
        } catch {
            print("There is currently no users available.")
        }
        
        return searchingTask
    }
    
    func updateTaskWith(
        identifier: UUID,
        title: String,
        completion: @escaping Success
    ) {
        let predicate = NSPredicate(format: "SELF MATCHES \(identifier)")
        let taskToBeUpdated = readTask(with: predicate)
        
        taskToBeUpdated?.title = title
        
        manager.saveChanges(completion: completion)
    }
    
    func delete(with identifier: UUID, completion: @escaping Success) {
        let context = manager.mainManagedObjectContext

        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: Task.self))
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = NSPredicate(format: "SELF MATCHES \(identifier)")

        do {
            let results = try context.fetch(fetchRequest)
            if let task = (results as? [Task])?.first {
                context.delete(task)
            }
            completion(true)
        } catch {
            print("Could not delete task.")
            completion(false)
        }
    }
    
    func deleteAll(completion: @escaping Success) {
        let context = manager.mainManagedObjectContext
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: Task.self))
        fetchRequest.returnsObjectsAsFaults = false
        
        do {
            let results = try context.fetch(fetchRequest)
            if let tasks = (results as? [Task]) {
                tasks.forEach { context.delete($0) }
            }
            completion(true)
        } catch {
            print("Could not delete all tasks.")
            completion(false)
        }
    }
}
