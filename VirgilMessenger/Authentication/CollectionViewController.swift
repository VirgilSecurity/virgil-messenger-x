//
//  CollectionViewController.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 12/8/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit
import PKHUD

class CollectionViewController: UICollectionViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return CoreDataHelper.sharedInstance.accounts.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "collectionCell", for: indexPath) as! CollectionViewCell
        
        let account = CoreDataHelper.sharedInstance.accounts[indexPath.row] as Account

        cell.usernameLabel.text = account.identity
        
        cell.letterLabel.text =  account.letter
        
        cell.avatarView.gradientLayer.colors = [account.colorPair.first, account.colorPair.second]
        cell.avatarView.gradientLayer.gradient = GradientPoint.bottomLeftTopRight.draw()
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let username = CoreDataHelper.sharedInstance.accounts[indexPath.row].identity else {
            Log.error("nil account")
            return
        }
        self.signIn(username: username)
    }
}

extension CollectionViewController {
    private func signIn(username: String) {
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
        let vc = UIStoryboard(name: "ChatList", bundle: Bundle.main).instantiateInitialViewController() as! UINavigationController
        self.switchNavigationStack(to: vc)
    }
    
    private func switchNavigationStack(to navigationController: UINavigationController) {
        let window = UIApplication.shared.keyWindow!
        
        UIView.transition(with: window, duration: UIConstants.TransitionAnimationDuration, options: .transitionCrossDissolve, animations: {
            window.rootViewController = navigationController
        })
    }
}
