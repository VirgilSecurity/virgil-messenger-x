//
//  ProfileViewController.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 11/22/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

class ProfileViewController: ViewController {
    
    private var eggCounter = 0
    private var player: AVAudioPlayer?
    @IBOutlet weak var avatarView: GradientView!
    @IBOutlet weak var letterLabel: UILabel!
    
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        self.tableView.tableFooterView = UIView(frame: .zero)
        self.tableView.delegate = self
        self.tableView.dataSource = self
        
        self.tableView.backgroundColor = UIColor(rgb: 0x2B303B)
        self.view.backgroundColor = UIColor(rgb: 0x2B303B)
        
        self.usernameLabel.text = TwilioHelper.sharedInstance.username
        
        let up = TwilioHelper.sharedInstance.username.uppercased().first!
        self.letterLabel.text =  String(describing: up)
        
        //FIXME
        let num = Int(CoreDataHelper.sharedInstance.myAccount!.numColorPair)
        let f = UIConstants.colorPairs[num].first
        let s = UIConstants.colorPairs[num].second
        self.avatarView.gradientLayer.colors = [f, s]
        self.avatarView.gradientLayer.gradient = GradientPoint.bottomLeftTopRight.draw()
        
    }
}

extension ProfileViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Logout", style: .destructive) { _ in
                UserDefaults.standard.set(nil, forKey: "last_username")
                
                let vc = UIStoryboard(name: "Authentication", bundle: Bundle.main).instantiateInitialViewController() as! UINavigationController
                
                self.switchNavigationStack(to: vc)
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            self.present(alert, animated: true)
        } else if indexPath.section == 1 {
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Delete account", style: .destructive) { _ in
                UserDefaults.standard.set(nil, forKey: "last_username")
                
                CoreDataHelper.sharedInstance.deleteAccount()
                VirgilHelper.sharedInstance.deleteStorageEntry(entry: TwilioHelper.sharedInstance.username)
                
                let vc = UIStoryboard(name: "Authentication", bundle: Bundle.main).instantiateInitialViewController() as! UINavigationController
                
                self.switchNavigationStack(to: vc)
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            self.present(alert, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = UIColor(rgb: 0x20232B)
    }
}


extension ProfileViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        if indexPath.section == 0 {
            cell.textLabel?.text = "Logout"
            cell.textLabel?.textColor = UIColor(rgb: 0x9E3621)
            cell.accessoryType = .none
        } else if indexPath.section == 1 {
            cell.textLabel?.text = "Delete account"
            cell.textLabel?.textColor = UIColor(rgb: 0x9E3621)
            cell.accessoryType = .none
        }
        
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
}
