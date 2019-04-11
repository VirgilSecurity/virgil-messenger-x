//
//  UIViewController+Alerts.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/3/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit

extension UIViewController {
    func alert(title: String? = nil, _ anyError: Error) {
        let error = anyError as? UserFriendlyError ?? .unknownError

        let alert = UIAlertController(title: title, message: error.rawValue, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

        self.present(alert, animated: true)
    }
}

extension UIViewController: UITextFieldDelegate {
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else {
            return true
        }

        guard string.rangeOfCharacter(from: ChatConstants.characterSet.inverted) == nil else {
            Log.debug("String contains special characters")
            return false
        }

        let newLength = text.count + string.count - range.length

        return newLength <= ChatConstants.limitLength
    }
}
