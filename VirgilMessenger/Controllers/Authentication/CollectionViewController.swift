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

        cell.letterLabel.text = account.letter

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

        guard currentReachabilityStatus != .notReachable else {
            PKHUD.sharedHUD.hide() { _ in
                let controller = UIAlertController(title: nil, message: "Please check your network connection", preferredStyle: .alert)
                controller.addAction(UIAlertAction(title: "OK", style: .default))

                self.present(controller, animated: true)
            }
            return
        }

        guard CoreDataHelper.sharedInstance.loadAccount(withIdentity: username) else {
            PKHUD.sharedHUD.hide() { _ in
                self.alert(VirgilHelper.UserFriendlyError.noUserOnDevice.localizedDescription)
            }
            return
        }
        let exportedCard = CoreDataHelper.sharedInstance.getAccountCard()

        VirgilHelper.sharedInstance.signIn(identity: username, card: exportedCard) { error in
            guard error == nil else {
                let message = error is VirgilHelper.UserFriendlyError ? error!.localizedDescription : "Something went wrong"
                PKHUD.sharedHUD.hide() { _ in
                    self.alert(message)
                }

                return
            }

            UserDefaults.standard.set(username, forKey: "last_username")
            PKHUD.sharedHUD.hide(true) { _ in
                self.goToChatList()
            }
        }
    }

    private func alert(_ message: String) {
        let alert = UIAlertController(title: message, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

        self.present(alert, animated: true)
    }

    private func goToChatList() {
        let vc = UIStoryboard(name: "TabBar", bundle: Bundle.main).instantiateInitialViewController() as! UINavigationController
        self.switchNavigationStack(to: vc)
    }

    private func switchNavigationStack(to navigationController: UINavigationController) {
        let window = UIApplication.shared.keyWindow!

        UIView.transition(with: window, duration: UIConstants.TransitionAnimationDuration, options: .transitionCrossDissolve, animations: {
            window.rootViewController = navigationController
        })
    }
}
