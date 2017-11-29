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
    
    @IBOutlet weak var tableView: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        self.tableView.tableFooterView = UIView(frame: .zero)
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }
}

extension ProfileViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            self.eggCounter += 1
            
            if self.eggCounter == 20 {
                self.eggCounter = 0
                
                guard let url = Bundle.main.url(forResource: "woody-woodpecker-laugh", withExtension: "mp3") else { return }
                
                do {
                    try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
                    try AVAudioSession.sharedInstance().setActive(true)
                    
                    
                    /* The following line is required for the player to work on iOS 11. Change the file type accordingly*/
                    player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
                    
                    /* iOS 10 and earlier require the following line:
                     player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileTypeMPEGLayer3) */
                    
                    guard let player = player else { return }
                    
                    player.play()
                    
                } catch let error {
                    print(error.localizedDescription)
                }
            }
        } else if indexPath.section == 1 {
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Logout", style: .destructive) { _ in
                UserDefaults.standard.set(nil, forKey: "last_username")
                
                let vc = UIStoryboard(name: "Authentication", bundle: Bundle.main).instantiateInitialViewController() as! UINavigationController
                
                self.switchNavigationStack(to: vc)
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            self.present(alert, animated: true)
        } else if indexPath.section == 2 {
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
}


extension ProfileViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        if indexPath.section == 0 {
            cell.textLabel?.text = TwilioHelper.sharedInstance.username
            cell.textLabel?.textColor = .black
            cell.accessoryType = .none
        }
        else if indexPath.section == 1 {
            cell.textLabel?.text = "Logout"
            cell.textLabel?.textColor = .red
            cell.accessoryType = .none
        } else if indexPath.section == 2 {
            cell.textLabel?.text = "Delete account"
            cell.textLabel?.textColor = .red
            cell.accessoryType = .none
        }
        
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
}
