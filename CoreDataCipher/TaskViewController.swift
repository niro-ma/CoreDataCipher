//
//  TaskViewController.swift
//  CoreDataCipher
//
//  Created by Niroshan Maheswaran on 07.05.21.
//

import UIKit

class TaskViewController: UIViewController {
    
    // MARK: - Outlets
    
    @IBOutlet private weak var tasksTableView: UITableView!
    @IBOutlet private weak var addTaskBarButtonItem: UIBarButtonItem!
    
    // MARK: - Private properties
    
    private let viewModel = TaskViewModelImpl(
        repository: TaskRepositoryImpl(
            manager: CoreDataManagerImpl(
                encryptionManager: EncryptionManagerImpl(),
                completion: ({})
            )
        )
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel.fetchTasks()
        tasksTableView.delegate = self
        tasksTableView.dataSource = self
    }
    
    @IBAction func addTaskBarButtonTapped(_ sender: UIBarButtonItem) {
        let ac = UIAlertController(title: "Enter Task", message: nil, preferredStyle: .alert)
        ac.addTextField()
        
        let submitAction = UIAlertAction(title: "Submit", style: .default) { [unowned ac, viewModel] _ in
            let textField = ac.textFields![0]
            
            viewModel.createTask(textField.text!) { [unowned self] success in
                self.viewModel.fetchTasks()
                
                DispatchQueue.main.async { [weak self] in
                    self?.tasksTableView.reloadData()
                }
            }
        }
        
        ac.addAction(submitAction)
        
        present(ac, animated: true)
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension TaskViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.tasks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: String(describing: TaskTableViewCell.self),
            for: indexPath
        ) as? TaskTableViewCell else {
            return UITableViewCell()
        }
        
        cell.titleLabel.text = viewModel.tasks[indexPath.row].title
        
        return cell
    }
}

class TaskTableViewCell: UITableViewCell {
    
    // MARK: - Outlets
    
    @IBOutlet weak var titleLabel: UILabel!
}
