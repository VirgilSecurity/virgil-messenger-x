//
//  ChatListViewController.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/18/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation
import UIKit
import PKHUD

class ChatListViewController: UIViewController, UITableViewDataSource, CellTapDelegate {
    
    @IBOutlet weak var ZeroChatsLabel: UILabel!
    
    func didTapOn(_ cell: UITableViewCell) {
        if let username = (cell as! ChatListCell).usernameLabel.text {
            TwilioHelper.sharedInstance.setChannel(withUsername: (username))
            
            if CoreDataHelper.sharedInstance.loadChannel(withName: username) == false {
                //CoreDataHelper.sharedInstance.createChannel(withName: TwilioHelper.sharedInstance.getCompanion(ofChannel: TwilioHelper.sharedInstance.selectedChannel))
                return
            }
            
            let channel = CoreDataHelper.sharedInstance.selectedChannel!
            let exportedCard = channel.card!
            VirgilHelper.sharedInstance.setChannelCard(exportedCard)
            
            self.performSegue(withIdentifier: "goToChat", sender: self)
        }
    }
    
    @IBAction func didTapLogOut(_ sender: Any) {
        self.navigationController?.isNavigationBarHidden = true
        self.dismiss(animated: true, completion: nil)
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
       
        if (TwilioHelper.sharedInstance.channels.subscribedChannels().contains {($0.attributes()?.values.contains { (value) -> Bool in
            value as! String == username
            })!
        }) {
            self.alert(withTitle: "You already have that channel")
        }
        else {
            HUD.show(.progress)
            TwilioHelper.sharedInstance.createChannel(withUsername: username) { error in
                HUD.flash(.success)
                if error == nil {
                    self.ZeroChatsLabel.isHidden = true
                    self.tableView.reloadData()
                    HUD.flash(.success)
                } else {
                    HUD.flash(.error)
                }
                
            }
        }
    }
    
    private func alert(withTitle: String) {
        let alert = UIAlertController(title: title, message: withTitle, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        self.present(alert, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        if let chatController = segue.destination as? ChatViewController {
            let pageSize = 10000
            
            let dataSource = DataSource(pageSize: pageSize)
            chatController.title = TwilioHelper.sharedInstance.getCompanion(ofChannel: TwilioHelper.sharedInstance.selectedChannel)
            chatController.dataSource = dataSource
            chatController.messageSender = dataSource.messageSender
        }
    }
    
    static let name = "ChatList"
    
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.register(UINib(nibName: ChatListCell.name, bundle: Bundle.main), forCellReuseIdentifier: ChatListCell.name)
        self.tableView.rowHeight = 80
        self.tableView.tableFooterView = UIView(frame: .zero)
        
        self.tableView.dataSource = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(ChatListViewController.reloadTableView(notification:)), name: Notification.Name(rawValue: TwilioHelper.Notifications.ChannelAdded.rawValue), object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        TwilioHelper.sharedInstance.selectedChannel = nil
        ZeroChatsLabel.isHidden =  TwilioHelper.sharedInstance.channels.subscribedChannels().count == 0 ? false : true
        VirgilHelper.sharedInstance.channelCard = nil
    }
    
    @objc private func reloadTableView(notification: Notification) {
        self.tableView.reloadData()
        ZeroChatsLabel.isHidden = true
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChatListCell.name) as! ChatListCell
        cell.tag = indexPath.row
        cell.delegate = self

        cell.usernameLabel.text = TwilioHelper.sharedInstance.getCompanion(ofChannel: indexPath.row)
        
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
