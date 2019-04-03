//
//  UIViewController+Alerts.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/3/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit

extension UIViewController {
    func alert(_ error: Error) {
        self.alert(error: error)
    }

    func alert(title: String? = nil, error anyError: Error) {
        let error = anyError as? UserFriendlyError ?? .unknownError

        let alert = UIAlertController(title: title, message: error.rawValue, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

        self.present(alert, animated: true)
    }
}
