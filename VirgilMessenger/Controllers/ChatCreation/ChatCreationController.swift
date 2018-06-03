//
//  ChatCreationController.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 5/30/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import UIKit
import PKHUD

class ChatCreationController: ViewController {
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.textField.delegate = self
        self.navigationController!.isNavigationBarHidden = false

        NotificationCenter.default.addObserver(self, selector: #selector(ChatCreationController.keyboardWillShow(notification:)), name: Notification.Name.UIKeyboardWillShow, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(ChatCreationController.keyboardWillHide(notification:)), name: Notification.Name.UIKeyboardWillHide, object: nil)
    }

    @objc func keyboardWillShow(notification: Notification) {
        guard let rect = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let time = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else {
                return
        }

        self.bottomConstraint.constant = 0 - rect.height
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

    @IBAction func backGroundTap(_ sender: Any) {
        self.view.endEditing(true)
    }

    @IBAction func segmentedControlChanged(_ sender: Any) {
        switch self.segmentedControl.selectedSegmentIndex {
        case 0:
            self.textField.placeholder = "Enter username"
        case 1:
            self.textField.placeholder = "Enter chat name"
        default:
            break
        }
    }

    @IBAction func closeTapped(_ sender: Any) {
        self.dismiss(animated: true)
    }

    @IBAction func createTapped(_ sender: Any) {
        guard let text = self.textField.text, !text.isEmpty else {
            self.textField.becomeFirstResponder()
            return
        }
        guard currentReachabilityStatus != .notReachable else {
            let controller = UIAlertController(title: self.title, message: "Please check your network connection", preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(controller, animated: true)

            return
        }

        switch self.segmentedControl.selectedSegmentIndex {
        case 0:
            let username = text.lowercased()

            guard username != TwilioHelper.sharedInstance.username else {
                self.alert(withTitle: "You need to communicate with other people :)")
                return
            }

            if (CoreDataHelper.sharedInstance.getChannels().contains {
                ($0 as Channel).name == username
            }) {
                self.alert(withTitle: "You already have this channel")
            } else {
                HUD.show(.progress)
                TwilioHelper.sharedInstance.createSingleChannel(with: username) { error in
                    HUD.flash(.success)
                    if error == nil {
                        HUD.flash(.success)
                        self.closeTapped(self)
                    } else {
                        HUD.flash(.error)
                    }
                }
            }
        case 1:
            let name = text
            if (CoreDataHelper.sharedInstance.getChannels().contains {
                ($0 as Channel).name == name
            }) {
                self.alert(withTitle: "You already have this channel")
            } else {
                HUD.show(.progress)
                TwilioHelper.sharedInstance.createGlobalChannel(withName: name) { error in
                    HUD.flash(.success)
                    if error == nil {
                        HUD.flash(.success)
                        self.closeTapped(self)
                    } else {
                        HUD.flash(.error)
                    }
                }
            }
        default:
            break
        }
    }
}
