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
    @IBOutlet weak var privacyLabel: UITextView!
    
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
        attriString.addAttribute(NSAttributedStringKey.font, value: UIFont.init(name: privacyLabel.font!.fontName, size: 13)!, range: range)
        
        let range1 = (text as NSString).range(of: "Terms of Service")
        attriString.addAttribute(NSAttributedStringKey.link, value: termsAndConditionsURL, range: range1)
        let range2 = (text as NSString).range(of: "Privacy Policy")
        attriString.addAttribute(NSAttributedStringKey.link, value: privacyURL, range: range2)
        
        privacyLabel.attributedText = attriString
    }
    
    private func textView(textView: UITextView, shouldInteractWithURL URL: NSURL, inRange characterRange: NSRange) -> Bool {
        if (URL.absoluteString == termsAndConditionsURL) {
            let myAlert = UIAlertController(title: "Terms", message: nil, preferredStyle: UIAlertControllerStyle.alert)
            myAlert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(myAlert, animated: true, completion: nil)
        } else if (URL.absoluteString == privacyURL) {
            let myAlert = UIAlertController(title: "Conditions", message: nil, preferredStyle: UIAlertControllerStyle.alert)
            myAlert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(myAlert, animated: true, completion: nil)
        }
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        NotificationCenter.default.addObserver(self, selector: #selector(RegistrationViewController.keyboardWillShow(notification:)), name: Notification.Name.UIKeyboardWillShow, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(RegistrationViewController.keyboardWillHide(notification:)), name: Notification.Name.UIKeyboardWillHide, object: nil)
            
        self.usernameTextField.delegate = self
    }
    
    @objc func keyboardWillShow(notification: Notification) {
        guard let rect = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let time = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else {
                return
        }
        
        // FIXME
        self.bottomConstraint.constant = rect.height
        UIView.animate(withDuration: time) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func keyboardWillHide(notification: Notification) {
        guard let time = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else {
                return
        }
        
        // FIXME
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
        
        VirgilHelper.sharedInstance.signUp(identity: username) { error, message in
            guard error == nil else {
                let message = message == nil ? "unknown error" : message
                PKHUD.sharedHUD.hide() { _ in
                    let controller = UIAlertController(title: self.title, message: message, preferredStyle: .alert)
                    controller.addAction(UIAlertAction(title: "OK", style: .default))
                    
                    self.present(controller, animated: true)
                }
                return
            }
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


extension RegistrationViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.signupButtonPressed(self)
        
        return false
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }
        if string.rangeOfCharacter(from: Constants.characterSet.inverted) != nil {
            Log.debug("string contains special characters")
            return false
        }
        let newLength = text.count + string.count - range.length
        return newLength <= Constants.limitLength
    }
}
