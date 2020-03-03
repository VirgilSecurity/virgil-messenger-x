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
            IdentityDefaults.shared.reset()
            self.goToLogin()
            return
        }

        do {
            try self.userAuthorizer.signIn()

            self.goToChatList()
        }
        catch {
            self.goToLogin()
        }
    }

    private func goToChatList() {
        self.switchNavigationStack(to: "TabBar")
    }

    private func goToLogin() {
        self.switchNavigationStack(to: AuthenticationViewController.name)
    }
}
