//
//  StartViewController.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 11/21/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit
import PKHUD

class StartViewController: ViewController {
    static let name = "Start"

    private let userAuthorizer: UserAuthorizer = UserAuthorizer()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard self.checkReachability() else {
            UserDefaults.standard.set(nil, forKey: UserAuthorizer.UserDefaultsIdentityKey)
            self.goToLogin()
            return
        }

        do {
            try self.userAuthorizer.signIn()

            self.goToChatList()
        } catch {
            self.goToLogin()
        }
    }

    private func goToChatList() {
        let vc = UIStoryboard(name: "TabBar", bundle: Bundle.main).instantiateInitialViewController() as! UINavigationController

        self.switchNavigationStack(to: vc)
    }

    private func goToLogin() {
        let vc = UIStoryboard(name: AuthenticationViewController.name,
                              bundle: Bundle.main).instantiateInitialViewController() as! UINavigationController

        self.switchNavigationStack(to: vc)
    }
}
