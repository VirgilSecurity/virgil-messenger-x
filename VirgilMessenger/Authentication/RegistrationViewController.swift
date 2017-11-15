//
//  RegistrationViewController.swift
//  VirgilSigner iOS
//
//  Created by Eugene Pyvovarov on 11/1/17.
//  Copyright © 2017 Virgil Security. All rights reserved.
//

import UIKit
import PKHUD

class RegistrationViewController: UIViewController {
    
    @IBOutlet weak var usernameTextField: UITextField!

    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    static let name = "Authentication"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        NotificationCenter.default.addObserver(self, selector: #selector(RegistrationViewController.keyboardWillShow(notification:)), name: Notification.Name.UIKeyboardWillShow, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(RegistrationViewController.keyboardWillHide(notification:)), name: Notification.Name.UIKeyboardWillHide, object: nil)
        
        self.usernameTextField.delegate = self
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
        guard let username = self.usernameTextField.text?.lowercased(), !username.isEmpty else {
            return
        }
        
        self.view.endEditing(true)
        
        PKHUD.sharedHUD.contentView = PKHUDProgressView()
        PKHUD.sharedHUD.show()
        
        VirgilHelper.sharedInstance.signIn(identity: username) { error in
            guard error == nil else {
                PKHUD.sharedHUD.hide() { _ in
                    let controller = UIAlertController(title: "Error", message: "Error while signing in", preferredStyle: .alert)
                    controller.addAction(UIAlertAction(title: "OK", style: .default))
                    
                    self.present(controller, animated: true)
                }
                return
            }
            CoreDataHelper.sharedInstance.signIn(withIdentity: username)

            UserDefaults.standard.set(username, forKey: "last_username")
            PKHUD.sharedHUD.hide() { _ in
                self.goToChatList()
            }
        }
    }
    
    @IBAction func signupButtonPressed(_ sender: Any) {
        guard let username = self.usernameTextField.text?.lowercased(), !username.isEmpty else {
            return
        }
        
        self.view.endEditing(true)
        
        PKHUD.sharedHUD.contentView = PKHUDProgressView()
        PKHUD.sharedHUD.show()
        
        VirgilHelper.sharedInstance.signUp(identity: username) { error in
            guard error == nil else {
                PKHUD.sharedHUD.hide() { _ in
                    let controller = UIAlertController(title: "Error", message: "Error while signing up", preferredStyle: .alert)
                    controller.addAction(UIAlertAction(title: "OK", style: .default))
                    
                    self.present(controller, animated: true)
                }
                return
            }
            
            UserDefaults.standard.set(username, forKey: "last_username")
            PKHUD.sharedHUD.hide() { _ in
                self.goToChatList()
            }
        }
    }
    
    private func goToChatList() {
        NotificationCenter.default.removeObserver(self)
        self.performSegue(withIdentifier: "goToChatList", sender: self)
    }
    
}


extension RegistrationViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.signinButtonPressed(self)
        
        return false
    }
}
