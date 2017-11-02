//
//  RegistrationViewController.swift
//  VirgilSigner iOS
//
//  Created by Eugene Pyvovarov on 11/1/17.
//  Copyright © 2017 Virgil Security. All rights reserved.
//

import UIKit
import VirgilSDK
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
        self.goToMainUi()
    }
    
    @IBAction func signupButtonPressed(_ sender: Any) {
        
        let crypto = VSSCrypto()
        let keyPair = crypto.generateKeyPair()
        let exportedPublicKey = crypto.export(keyPair.publicKey)
        
        let identity = "unique1291234142"
        let identityType = "name"
        
        let csr = VSSCreateUserCardRequest(identity: identity, identityType: identityType, publicKeyData: exportedPublicKey, data: ["deviceId": "testDevice123"])
        
        let signer = VSSRequestSigner(crypto: crypto)
        try! signer.selfSign(csr, with: keyPair.privateKey)
        
        let exportedCSR = csr.exportData()
        
        print(exportedCSR)
        
        let request = try! ServiceRequest(url: URL(string: "https://twilio.virgilsecurity.com/v1/users")!, method: ServiceRequest.Method.post, headers: ["Content-Type":"application/json"], params: ["csr" : exportedCSR])
        
        let connection = ServiceConnection()
        
        
        
        //let response = try! connection.send(request)
        

    }
    
    private func goToMainUi() {
        self.performSegue(withIdentifier: "goToChatList", sender: self)
    }
}


extension RegistrationViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.signinButtonPressed(self)
        
        return false
    }
}
