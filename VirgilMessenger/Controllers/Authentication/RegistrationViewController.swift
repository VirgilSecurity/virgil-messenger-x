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

    let termsAndConditionsURL = "https://virgilsecurity.com/terms-of-service"
    let privacyURL = "https://virgilsecurity.com/privacy-policy"

    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        self.viewDidAppear(animated)

        privacyLabel.delegate = self
        privacyLabel.textContainerInset = UIEdgeInsets.zero
        privacyLabel.linkTextAttributes = [NSAttributedStringKey.foregroundColor.rawValue: UIColor(rgb: 0x9E3621)]

        let text = (privacyLabel.text)!
        let attriString = NSMutableAttributedString(string: text)

        let range = (text as NSString).range(of: text)
        attriString.addAttribute(NSAttributedStringKey.foregroundColor, value: UIColor(rgb: 0x6B6B70), range: range)
        attriString.addAttribute(NSAttributedStringKey.font, value: UIFont(name: privacyLabel.font!.fontName, size: 13)!, range: range)

        let range1 = (text as NSString).range(of: "Terms of Service")
        attriString.addAttribute(NSAttributedStringKey.link, value: termsAndConditionsURL, range: range1)
        let range2 = (text as NSString).range(of: "Privacy Policy")
        attriString.addAttribute(NSAttributedStringKey.link, value: privacyURL, range: range2)

        privacyLabel.attributedText = attriString
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(RegistrationViewController.keyboardWillShow(notification:)), name: Notification.Name.UIKeyboardWillShow, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(RegistrationViewController.keyboardWillHide(notification:)), name: Notification.Name.UIKeyboardWillHide, object: nil)

        self.usernameTextField.delegate = self
    }

    @objc func keyboardWillShow(notification: Notification) {
        guard let rect = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let time = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else {
                return
        }

        self.bottomConstraint.constant = rect.height
        UIView.animate(withDuration: time) {
            self.view.layoutIfNeeded()
        }
    }

    @objc func keyboardWillHide(notification: Notification) {
        guard let time = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else {
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
        NotificationCenter.default.removeObserver(self)
    }

    @IBAction func signupButtonPressed(_ sender: Any) {
        guard let username = self.usernameTextField.text?.lowercased(), !username.isEmpty else {
            self.usernameTextField.becomeFirstResponder()
            return
        }
        self.view.endEditing(true)

        PKHUD.sharedHUD.contentView = PKHUDProgressView()
        PKHUD.sharedHUD.show()

        guard currentReachabilityStatus != .notReachable else {
            PKHUD.sharedHUD.hide() { _ in
                let controller = UIAlertController(title: nil, message: "Please check your network connection", preferredStyle: .alert)
                controller.addAction(UIAlertAction(title: "OK", style: .default))

                self.present(controller, animated: true)
            }
            return
        }

        VirgilHelper.sharedInstance.signUp(identity: username) { exportedCard, error in
            guard error == nil, let exportedCard = exportedCard else {
                var message = "Something went wrong"
                if let err = error as? VirgilHelper.UserFriendlyError {
                    message = err.rawValue
                }

                PKHUD.sharedHUD.hide() { _ in
                    let controller = UIAlertController(title: self.title, message: message, preferredStyle: .alert)
                    controller.addAction(UIAlertAction(title: "OK", style: .default))

                    self.present(controller, animated: true)
                }
                return
            }
            CoreDataHelper.sharedInstance.createAccount(withIdentity: username, exportedCard: exportedCard)
            UserDefaults.standard.set(username, forKey: "last_username")

            PKHUD.sharedHUD.hide(true) { _ in
                self.goToChatList()
            }
        }
    }

    private func goToChatList() {
        NotificationCenter.default.removeObserver(self)

        let vc = UIStoryboard(name: "ChatList", bundle: Bundle.main).instantiateInitialViewController() as! UINavigationController
        self.switchNavigationStack(to: vc)
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
