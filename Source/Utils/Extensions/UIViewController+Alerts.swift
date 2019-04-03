//
//  UIViewController+Alerts.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/3/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit

extension UIViewController {
    func alertNoConnection() {
        self.alert("Please check your network connection")
    }

    func alert(_ message: String? = nil) {
        self.alert(title: message)
    }

    func alert(title: String? = nil, message: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

        self.present(alert, animated: true)
    }
}
