//
//  UIViewController.swift
//  Morse
//
//  Created by Yevhen Pyvovarov on 4/3/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit

extension UIViewController {
    func alert(title: String? = nil, _ anyError: Error, handler: ((UIAlertAction) -> Void)? = nil) {
        let error = UserFriendlyError(from: anyError)

        let message = error.rawValue

        let alert: UIAlertController = UIAlertController(title: title,
                                                         message: message,
                                                         preferredStyle: .alert)

        let okAction = UIAlertAction(title: "OK", style: .default, handler: handler)
        alert.addAction(okAction)

        self.presentedViewController?.dismiss(animated: true, completion: nil)

        self.present(alert, animated: true)
    }
}

extension UIViewController: UITextFieldDelegate {
    public func textField(_ textField: UITextField,
                          shouldChangeCharactersIn range: NSRange,
                          replacementString string: String) -> Bool {
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

extension UIViewController {
    @objc func popToRoot() {
        self.navigationController?.popToRootViewController(animated: true)
    }
}
