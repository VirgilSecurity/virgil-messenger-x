//
//  RegistrationViewController.swift
//  VirgilSigner iOS
//
//  Created by Eugene Pyvovarov on 11/1/17.
//  Copyright © 2017 Virgil Security. All rights reserved.
//

import UIKit
import PKHUD

class RegistrationViewController: ViewController {
    
    @IBOutlet weak var usernameTextField: UITextField!
    private let limitLength = 32
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!

    let pickerView = UIPickerView()
    
    let characterset = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,-()/='+:?!%&*<>;{}@#_")
   
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        NotificationCenter.default.addObserver(self, selector: #selector(RegistrationViewController.keyboardWillShow(notification:)), name: Notification.Name.UIKeyboardWillShow, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(RegistrationViewController.keyboardWillHide(notification:)), name: Notification.Name.UIKeyboardWillHide, object: nil)
        
        pickerView.dataSource = self
        pickerView.delegate = self
        
        self.usernameTextField.delegate = self
        self.usernameTextField.inputView = self.pickerView
        
    }
    
    @objc func keyboardWillShow(notification: Notification) {
        guard let frame = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let time = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else {
                return
        }
        
        self.bottomConstraint.constant = frame.height
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
    
    @IBAction func signinButtonPressed(_ sender: Any) {
        self.usernameTextField.inputView = self.pickerView
        guard let username = self.usernameTextField.text?.lowercased(), !username.isEmpty else {
            self.usernameTextField.isHidden = false
            self.usernameTextField.inputView = self.pickerView
            self.usernameTextField.becomeFirstResponder()
            return
        }
        
        self.view.endEditing(true)
        
        PKHUD.sharedHUD.contentView = PKHUDProgressView()
        PKHUD.sharedHUD.show()
        
        VirgilHelper.sharedInstance.signIn(identity: username) { error, message in
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
    
    @IBAction func signupButtonPressed(_ sender: Any) {
        self.usernameTextField.inputView = nil
        self.usernameTextField.reloadInputViews()
        guard let username = self.usernameTextField.text?.lowercased(), !username.isEmpty else {
            self.usernameTextField.isHidden = false
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
    
    @IBAction func logoTapped(_ sender: Any) {
        Log.debug("Logo tapped")
        openUrl(urlStr: "https://virgilsecurity.com")
    }
    
    private func openUrl(urlStr: String) {
        if let url = NSURL(string:urlStr) {
            UIApplication.shared.open(url as URL, options: [:], completionHandler: nil)
        }
    }
    
}


extension RegistrationViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.signinButtonPressed(self)
        
        return false
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }
        if string.rangeOfCharacter(from: characterset.inverted) != nil {
            Log.debug("string contains special characters")
            return false
        }
        let newLength = text.count + string.count - range.length
        return newLength <= limitLength
    }
}

extension RegistrationViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return CoreDataHelper.sharedInstance.accounts.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return CoreDataHelper.sharedInstance.accounts[row].identity!
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.usernameTextField.text = CoreDataHelper.sharedInstance.accounts[row].identity ?? "Error name"
    }
}
