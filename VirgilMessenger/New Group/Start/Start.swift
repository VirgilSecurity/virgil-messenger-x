//
//  Start.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 11/21/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit
import PKHUD

class StartViewController: ViewController {
    static let name = "Start"

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let username = UserDefaults.standard.string(forKey: "last_username"),
            !username.isEmpty {
            PKHUD.sharedHUD.contentView = PKHUDProgressView()
            PKHUD.sharedHUD.show()

            guard currentReachabilityStatus != .notReachable else {
                PKHUD.sharedHUD.hide() { _ in
                    let controller = UIAlertController(title: nil, message: "Please check your network connection", preferredStyle: .alert)
                    controller.addAction(UIAlertAction(title: "OK", style: .default))

                    self.present(controller, animated: true)
                    UserDefaults.standard.set(nil, forKey: "last_username")
                    self.goToLogin()
                }
                return
            }

            guard CoreDataHelper.sharedInstance.loadAccount(withIdentity: username) else {
                PKHUD.sharedHUD.hide() { _ in
                    self.goToLogin()
                }
                return
            }
            let exportedCard = CoreDataHelper.sharedInstance.getAccountCard()

            VirgilHelper.sharedInstance.signIn(identity: username, card: exportedCard) { error in
                guard error == nil else {
                    PKHUD.sharedHUD.hide(true) { _ in
                        self.goToLogin()
                    }
                    return
                }

                PKHUD.sharedHUD.hide(true) { _ in
                    self.goToChatList()
                }
            }
        } else {
            self.goToLogin()
        }
    }

    private func goToChatList() {
        let vc = UIStoryboard(name: "TabBar", bundle: Bundle.main).instantiateInitialViewController() as! UINavigationController

        self.switchNavigationStack(to: vc)
    }

    private func goToLogin() {
        let vc = UIStoryboard(name: "Authentication", bundle: Bundle.main).instantiateInitialViewController() as! UINavigationController

        self.switchNavigationStack(to: vc)
    }
}
