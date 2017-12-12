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

class ChatListViewController: ViewController {
    
    @IBOutlet weak var noChatsView: UIView!
    private let limitLength = 32
    let characterset = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,-()/='+:?!%&*<>;{}@#_")
    
    @IBAction func didTapAdd(_ sender: Any) {
        let alertController = UIAlertController(title: "Add", message: "Enter username", preferredStyle: .alert)
        
        alertController.addTextField(configurationHandler: {
            $0.placeholder = "Username"
            $0.delegate = self
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
        let username = username.lowercased()
    
        guard (username != TwilioHelper.sharedInstance.username) else {
            self.alert(withTitle: "You need to communicate with other people :)")
            return
        }
        
        if (TwilioHelper.sharedInstance.channels.subscribedChannels().contains {
            ($0.attributes()?.values.contains { (value) -> Bool in
                value as! String == username
            })!
        }) {
            self.alert(withTitle: "You already have this channel")
        }
        else {
            HUD.show(.progress)
            TwilioHelper.sharedInstance.createChannel(withUsername: username) { error in
                HUD.flash(.success)
                if error == nil {
                    self.noChatsView.isHidden = true
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
    
    static let name = "ChatList"
    
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.register(UINib(nibName: ChatListCell.name, bundle: Bundle.main), forCellReuseIdentifier: ChatListCell.name)
        self.tableView.rowHeight = 94
        self.tableView.tableFooterView = UIView(frame: .zero)
        
        self.tableView.dataSource = self
        self.tableView.backgroundColor = UIColor(rgb: 0x2B303B)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ChatListViewController.reloadTableView(notification:)), name: Notification.Name(rawValue: TwilioHelper.Notifications.ChannelAdded.rawValue), object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        TwilioHelper.sharedInstance.selectedChannel = nil
        noChatsView.isHidden =  TwilioHelper.sharedInstance.channels.subscribedChannels().count == 0 ? false : true
        //FIXME
        //VirgilHelper.sharedInstance.channelCard = nil
    }
    
    @objc private func reloadTableView(notification: Notification) {
        self.tableView.reloadData()
        noChatsView.isHidden = true
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension ChatListViewController: UITableViewDataSource {
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
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = UIColor(rgb: 0x2B303B)
    }
    
    /*
     func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
         if editingStyle == .delete {
             CoreDataHelper.sharedInstance.deleteChannel(withName: TwilioHelper.sharedInstance.getCompanion(ofChannel: indexPath.row))
             TwilioHelper.sharedInstance.destroyChannel(indexPath.row) {
             self.tableView.reloadData()
             }
         }
     }*/
}

extension ChatListViewController: CellTapDelegate {
    func didTapOn(_ cell: UITableViewCell) {
        if let username = (cell as! ChatListCell).usernameLabel.text {
            TwilioHelper.sharedInstance.setChannel(withUsername: (username))
            
            if CoreDataHelper.sharedInstance.loadChannel(withName: username) == false {
                //CoreDataHelper.sharedInstance.createChannel(withName: TwilioHelper.sharedInstance.getCompanion(ofChannel: TwilioHelper.sharedInstance.selectedChannel))
                return
            }
            
            guard let channel = CoreDataHelper.sharedInstance.selectedChannel,
                let exportedCard = channel.card
                else {
                    Log.error("can't find selected channel in Core Data")
                    return
            }
            
            VirgilHelper.sharedInstance.setChannelCard(exportedCard)
            
            self.performSegue(withIdentifier: "goToChat", sender: self)
        }
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
}

extension ChatListViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }
        if string.rangeOfCharacter(from: characterset.inverted) != nil {
            Log.debug("string contains special characters")
            return false
        }
        let newLength = text.count + string.count - range.length
        return newLength <= limitLength
    }
}
