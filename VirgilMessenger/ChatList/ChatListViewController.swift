//
//  ChatListViewController.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/18/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation
import UIKit

class ChatListViewController: UIViewController, UITableViewDataSource, CellTapDelegate {
    
    func didTapOn(_ cell: UITableViewCell) {
        TwilioHelper.sharedInstance.selectedChannel = cell.tag

        self.performSegue(withIdentifier: "goToChat", sender: self)
    }
    
    @IBAction func didTapAdd(_ sender: Any) {
        let alertController = UIAlertController(title: "Add", message: "Enter username", preferredStyle: .alert)
        
        alertController.addTextField(configurationHandler: {
            $0.placeholder = "Username"
        })
        
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            guard let username = alertController.textFields?.first?.text else {
                return
            }
            
            self.addChat(withUsername: username)
        }))
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in }))
        
        self.present(alertController, animated: true)
    }
    
    private func addChat(withUsername username: String) {
        TwilioHelper.sharedInstance.createChannel(withUsername: username) { error in
            let title = error == nil ? "Success" : "Error"
            
            let alert = UIAlertController(title: title, message: "", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            
            self.present(alert, animated: true)
            
            self.tableView.reloadData()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        if let chatController = segue.destination as? ChatViewController {
            let pageSize = 10
            
            let dataSource = DataSource(pageSize: pageSize)
            chatController.dataSource = dataSource
            chatController.messageSender = dataSource.messageSender
        }
    }
    
    static let name = "ChatList"
    
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        TwilioHelper.authorize(username: "test", device: "iPhone")
        TwilioHelper.sharedInstance.initialize() {
            sleep(1)
            self.tableView.reloadData()
        }
     
        self.tableView.register(UINib(nibName: ChatListCell.name, bundle: Bundle.main), forCellReuseIdentifier: ChatListCell.name)
        self.tableView.rowHeight = 45
        self.tableView.tableFooterView = UIView(frame: .zero)
        
        self.tableView.dataSource = self
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChatListCell.name) as! ChatListCell
        
        cell.usernameLabel.text = TwilioHelper.sharedInstance.channels.subscribedChannels()[indexPath.row].friendlyName
        cell.tag = indexPath.row
        cell.delegate = self
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let channels = TwilioHelper.sharedInstance.channels else { return 0 }
        return channels.subscribedChannels().count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
}
