//
//  RegistrationViewController.swift
//  VirgilSigner iOS
//
//  Created by Eugene Pyvovarov on 11/1/17.
//  Copyright © 2017 Virgil Security. All rights reserved.
//

import UIKit
import PKHUD

class RegistrationViewController: ViewController, UITextViewDelegate {
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var ejabberdHostTextField: UITextField!
    @IBOutlet weak var pushHostTextField: UITextField!
    @IBOutlet weak var backendHostTextField: UITextField!

    private let userAuthorizer: UserAuthorizer = UserAuthorizer()

    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: animated)

        self.viewDidAppear(animated)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.keyboardWillShow(notification:)),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.keyboardWillHide(notification:)),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)

        self.usernameTextField.delegate = self
    }

    @objc func keyboardWillShow(notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey],
            let keyboardFrameValue = keyboardFrame as? NSValue,
            let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey],
            let animationDurationNumber = animationDuration as? NSNumber
        else {
            return
        }

        self.bottomConstraint.constant = keyboardFrameValue.cgRectValue.height

        UIView.animate(withDuration: animationDurationNumber.doubleValue) {
            self.view.layoutIfNeeded()
        }
    }

    @objc func keyboardWillHide(notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey],
            let animationDurationNumber = animationDuration as? NSNumber
        else {
            return
        }

        self.bottomConstraint.constant = 0

        UIView.animate(withDuration: animationDurationNumber.doubleValue) {
            self.view.layoutIfNeeded()
        }
    }

    @IBAction func backgroundTap(_ sender: Any) {
        self.view.endEditing(true)
    }

    @IBAction func signupButtonPressed(_ sender: Any) {
        guard let username = self.usernameTextField.text?.lowercased(), !username.isEmpty else {
            self.usernameTextField.becomeFirstResponder()
            return
        }

        guard let ejabberdHost = self.ejabberdHostTextField.text?.lowercased(), !ejabberdHost.isEmpty else {
            self.ejabberdHostTextField.becomeFirstResponder()
            return
        }

        guard let pushHost = self.pushHostTextField.text?.lowercased(), !pushHost.isEmpty else {
            self.pushHostTextField.becomeFirstResponder()
            return
        }

        guard let backendHost = self.backendHostTextField.text?.lowercased(), !backendHost.isEmpty else {
            self.backendHostTextField.becomeFirstResponder()
            return
        }

        self.view.endEditing(true)

        guard self.checkReachability() else {
            return
        }

        HUD.show(.progress)

        self.userAuthorizer.signUp(identity: username,
                                   ejabberdHost: ejabberdHost,
                                   pushHost: pushHost,
                                   backendHost: backendHost)
        { error in
            DispatchQueue.main.async {
                HUD.hide { _ in
                    if let error = error {
                        self.alert(title: self.title, error)
                    }
                    else {
                        self.goToChatList()
                    }
                }
            }
        }
    }

    private func goToChatList() {
        Notifications.removeObservers(self)

        self.switchNavigationStack(to: .tabBar)
    }

    private func openUrl(urlStr: String) {
        if let url = NSURL(string: urlStr) {
            UIApplication.shared.open(url as URL, options: [:], completionHandler: nil)
        }
    }
}
