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
    @IBOutlet weak var privacyLabel: UITextView!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!

    private let userAuthorizer: UserAuthorizer = UserAuthorizer()

    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        self.viewDidAppear(animated)

        privacyLabel.delegate = self
        privacyLabel.textContainerInset = UIEdgeInsets.zero
        privacyLabel.linkTextAttributes = [.foregroundColor: UIColor(rgb: 0x9E3621)]

        let text = (privacyLabel.text)!
        let attriString = NSMutableAttributedString(string: text)

        let range = (text as NSString).range(of: text)
        attriString.addAttribute(.foregroundColor,
                                 value: UIColor(rgb: 0x6B6B70),
                                 range: range)
        attriString.addAttribute(.font,
                                 value: UIFont(name: privacyLabel.font!.fontName, size: 13)!,
                                 range: range)

        let range1 = (text as NSString).range(of: "Terms of Service")
        attriString.addAttribute(.link,
                                 value: URLConstansts.termsAndConditionsURL,
                                 range: range1)

        let range2 = (text as NSString).range(of: "Privacy Policy")
        attriString.addAttribute(.link,
                                 value: URLConstansts.privacyURL,
                                 range: range2)

        privacyLabel.attributedText = attriString
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
        guard let rect = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let time = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else {
                return
        }

        self.bottomConstraint.constant = rect.height
        UIView.animate(withDuration: time) {
            self.view.layoutIfNeeded()
        }
    }

    @objc func keyboardWillHide(notification: Notification) {
        guard let time = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else {
                return
        }

        self.bottomConstraint.constant = 0
        UIView.animate(withDuration: time) {
            self.view.layoutIfNeeded()
        }
    }

    @IBAction func backgroundTap(_ sender: Any) {
        self.view.endEditing(true)
    }

    deinit {
        Notifications.removeObservers(self)
    }

    @IBAction func signupButtonPressed(_ sender: Any) {
        guard let username = self.usernameTextField.text?.lowercased(), !username.isEmpty else {
            self.usernameTextField.becomeFirstResponder()
            return
        }
        self.view.endEditing(true)

        guard self.checkReachability() else {
            return
        }

        HUD.show(.progress)

        self.userAuthorizer.signUp(identity: username) { error in
            DispatchQueue.main.async {
                HUD.hide() { _ in
                    if let error = error {
                        self.alert(title: self.title, error)
                    } else {
                        self.goToChatList()
                    }
                }
            }
        }
    }

    private func goToChatList() {
        Notifications.removeObservers(self)

        self.switchNavigationStack(to: "TabBar")
    }

    private func openUrl(urlStr: String) {
        if let url = NSURL(string:urlStr) {
            UIApplication.shared.open(url as URL, options: [:], completionHandler: nil)
        }
    }
}

extension RegistrationViewController {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.signupButtonPressed(self)

        return false
    }
}
