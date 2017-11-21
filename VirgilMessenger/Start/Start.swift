//
//  Start.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 11/21/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation
import UIKit
import PKHUD

class StartViewController: ViewController {

    static let name = "Start"
    override func viewDidAppear(_ animated: Bool) {
        
        if let username = UserDefaults.standard.string(forKey: "last_username"),
            !username.isEmpty {
            PKHUD.sharedHUD.contentView = PKHUDProgressView()
            PKHUD.sharedHUD.show()
            VirgilHelper.sharedInstance.signIn(identity: username) { error, title in
                guard error == nil else {
                    PKHUD.sharedHUD.hide(true) { _ in
                        self.goToLogin()
                    }
                    return
                }
                
                PKHUD.sharedHUD.hide(true) { _ in
                    self.goToMain()
                }
            }
        }
        else {
            self.goToLogin()
        }
    }
    
    private func goToMain() {
        let vc = UIStoryboard(name: "ChatList", bundle: Bundle.main).instantiateInitialViewController() as! UINavigationController
        
        self.switchNavigationStack(to: vc)
    }
    
    private func goToLogin() {
        let vc = UIStoryboard(name: "Authentication", bundle: Bundle.main).instantiateInitialViewController() as! UINavigationController
        
        self.switchNavigationStack(to: vc)
    }
}
