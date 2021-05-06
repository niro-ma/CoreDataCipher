//
//  TaskViewModel.swift
//  CoreDataCipher
//
//  Created by Niroshan Maheswaran on 07.05.21.
//

import Foundation

protocol TaskViewModel {
    
    var tasks: [Task] { get }
    
    func fetchTasks()
    
    func createTask(_ task: String, completion: @escaping Success)
    
    func updateTask(_ task: Task, withTitle title: String, completion: @escaping Success)
    
    func deleteTask(_ task: Task, completion: @escaping Success)
    
    func deleteAllTasks(_ completion: @escaping Success)
}

class TaskViewModelImpl: TaskViewModel {
    
    // MARK: - Public properties
    
    private(set) var tasks: [Task] = []
    
    // MARK: - Private properties
    
    private let repository: TasksRepository
    
    // MARK: - Public methods
    
    init(repository: TasksRepository) {
        self.repository = repository
    }
    
    func fetchTasks() {
        tasks = repository.readAllTasks()
    }
    
    func createTask(_ task: String, completion: @escaping Success) {
        repository.createTask(task, completion: completion)
    }
    
    func updateTask(_ task: Task, withTitle title: String, completion: @escaping Success) {
        repository.updateTaskWith(identifier: task.taskId!, title: title, completion: completion)
    }
    
    func deleteTask(_ task: Task, completion: @escaping Success) {
        repository.delete(with: task.taskId!, completion: completion)
    }
    
    func deleteAllTasks(_ completion: @escaping Success) {
        repository.deleteAll(completion: completion)
    }
}
