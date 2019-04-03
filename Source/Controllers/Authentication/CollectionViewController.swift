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
    private let userAuthorizer: UserAuthorizer = UserAuthorizer()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return CoreDataHelper.shared.accounts.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "collectionCell", for: indexPath) as! CollectionViewCell

        let account = CoreDataHelper.shared.accounts[indexPath.row] as Account

        cell.usernameLabel.text = account.identity

        cell.letterLabel.text = account.letter

        cell.avatarView.gradientLayer.colors = [account.colorPair.first, account.colorPair.second]
        cell.avatarView.gradientLayer.gradient = GradientPoint.bottomLeftTopRight.draw()

        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let username = CoreDataHelper.shared.accounts[indexPath.row].identity else {
            Log.error("nil account")
            return
        }
        self.signIn(username: username)
    }
}

extension CollectionViewController {
    private func signIn(username: String) {
        guard self.checkReachability() else {
            return
        }

        do {
            try self.userAuthorizer.signIn(identity: username)

            self.goToChatList()
        } catch {
            self.alert(error)
        }
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
