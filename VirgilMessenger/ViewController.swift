//
//  ViewController.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit
import CoreData

class ViewController: UIViewController, UITextFieldDelegate {
    enum Notifications: String {
        case Error = "ViewController.Notifications.Error"
    }

    enum NotificationKeys: String {
        case Error = "ViewController.NotificationKeys.Error"
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    var isRootViewController: Bool {
        return self.navigationController?.viewControllers.count ?? 1 == 1
    }

    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.processError(notification:)),
                                               name: Notification.Name(rawValue: ViewController.Notifications.Error.rawValue),
                                               object: nil)

        super.viewDidLoad()
    }

    deinit {
        NotificationCenter.default.removeObserver(self,
                                                  name: Notification.Name(rawValue: ViewController.Notifications.Error.rawValue),
                                                  object: nil)
        Log.debug(self.description)
    }

    @objc private func processError(notification: Notification) {
        guard  let userInfo = notification.userInfo,
            let error = userInfo[ViewController.NotificationKeys.Error.rawValue] as? Error else {
                return
        }

        self.alert(error.localizedDescription)
    }

    func switchNavigationStack(to navigationController: UINavigationController) {
        let window = UIApplication.shared.keyWindow!

        UIView.transition(with: window, duration: UIConstants.TransitionAnimationDuration, options: .transitionCrossDissolve, animations: {
            window.rootViewController = navigationController
        })
    }

    func alert(_ message: String) {
        let alert = UIAlertController(title: message, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

        self.present(alert, animated: true)
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }
        if string.rangeOfCharacter(from: ChatConstants.characterSet.inverted) != nil {
            Log.debug("string contains special characters")
            return false
        }
        let newLength = text.count + string.count - range.length
        return newLength <= ChatConstants.limitLength
    }
}
