//
//  LoginViewController.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 11/27/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation
import UIKit
import PKHUD

class LoginViewController: ViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!

    @IBAction func cancelTapped(_ sender: Any) {
        self.dismiss(animated: true)
    }
    
    override func viewDidLoad() {
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return CoreDataHelper.sharedInstance.accounts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        
        cell.textLabel?.text = CoreDataHelper.sharedInstance.accounts[indexPath.row].identity ?? "Error name"
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let username = CoreDataHelper.sharedInstance.accounts[indexPath.row].identity else {
            Log.error("nil account")
            return
        }
        signIn(username: username)
    }
    
    private func signIn(username: String) {
        
        self.view.endEditing(true)
        
        PKHUD.sharedHUD.contentView = PKHUDProgressView()
        PKHUD.sharedHUD.show()
        
        VirgilHelper.sharedInstance.signIn(identity: username) { error, message in
            guard error == nil else {
                let message = message == nil ? "unknown error" : message
                PKHUD.sharedHUD.hide() { _ in
                    let controller = UIAlertController(title: self.title, message: message, preferredStyle: .alert)
                    controller.addAction(UIAlertAction(title: "OK", style: .default))
                    
                    self.present(controller, animated: true)
                }
                
                return
            }
            
            UserDefaults.standard.set(username, forKey: "last_username")
            PKHUD.sharedHUD.hide(true) { _ in
                self.goToChatList()
            }
        }
    }
    
    private func goToChatList() {
        NotificationCenter.default.removeObserver(self)
        
        let vc = UIStoryboard(name: "ChatList", bundle: Bundle.main).instantiateInitialViewController() as! UINavigationController
        self.switchNavigationStack(to: vc)
    }
}
