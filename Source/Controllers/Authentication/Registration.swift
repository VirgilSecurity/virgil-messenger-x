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

        self.setupUsernameTextField()
        self.setupPrivacyLabel()
    }

    private func setupUsernameTextField() {
        self.usernameTextField.delegate = self

        let placeholderColor = UIColor(rgb: 0x8E8F93)
        let placeholderAttributes = [NSAttributedString.Key.foregroundColor: placeholderColor]
        let placeholderString = NSAttributedString.init(string: "Your username",
                                                        attributes: placeholderAttributes)
        self.usernameTextField.attributedPlaceholder = placeholderString
    }

    private func setupPrivacyLabel() {
        self.privacyLabel.delegate = self
        self.privacyLabel.textContainerInset = UIEdgeInsets.zero
        self.privacyLabel.linkTextAttributes = [.foregroundColor: UIColor(rgb: 0x9E3621)]

        let text = self.privacyLabel.text!
        let attriString = NSMutableAttributedString(string: text)
        let nsText = text as NSString

        let range = nsText.range(of: text)
        attriString.addAttribute(.foregroundColor,
                                 value: UIColor(rgb: 0x6B6B70),
                                 range: range)

        attriString.addAttribute(.font,
                                 value: UIFont.systemFont(ofSize: 13, weight: .semibold),
                                 range: range)

        let range1 = nsText.range(of: "Terms of Service")
        attriString.addAttribute(.link,
                                 value: URLConstants.termsAndConditionsURL,
                                 range: range1)

        let range2 = nsText.range(of: "Privacy Policy")
        attriString.addAttribute(.link,
                                 value: URLConstants.privacyURL,
                                 range: range2)

        self.privacyLabel.attributedText = attriString
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
        self.view.endEditing(true)

        guard self.checkReachability() else {
            return
        }

        HUD.show(.progress)

        self.userAuthorizer.signUp(identity: username) { error in
            DispatchQueue.main.async {
                HUD.hide { _ in
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
        if let url = NSURL(string: urlStr) {
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
