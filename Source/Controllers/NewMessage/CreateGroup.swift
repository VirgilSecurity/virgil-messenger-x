//
//  CreateGroup.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/12/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit
import PKHUD

class CreateGroupViewController: ViewController {
    @IBOutlet weak var letterLabel: UILabel!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var createButton: UIBarButtonItem!
    @IBOutlet weak var usersListHeight: NSLayoutConstraint!
    @IBOutlet weak var scrollView: UIScrollView!

    public var members: [Storage.Channel] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupNameTextField()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.updateScrollViewContentSize()
    }

    private func setupNameTextField() {
        self.nameTextField.delegate = self

        let placeholderColor = UIColor(rgb: 0x8E8F93)
        let placeholderAttributes = [NSAttributedString.Key.foregroundColor: placeholderColor]
        let placeholderString = NSAttributedString.init(string: "Group Name",
                                                        attributes: placeholderAttributes)
        self.nameTextField.attributedPlaceholder = placeholderString
    }

    private func updateScrollViewContentSize() {
        let bounds = UIScreen.main.bounds

        // FIXME
        let height = max(self.usersListHeight.constant + 170, bounds.height - self.topBarHeight)

        self.scrollView.contentSize = CGSize(width: bounds.width, height: height)
    }

    @IBAction func createTapped(_ sender: Any) {
//        guard let name = nameTextField.text else {
//            return
//        }
//
//        self.view.endEditing(true)
//
//        guard self.checkReachability(), Configurator.isUpdated else {
//            return
//        }
//
//        let hudShow = {
//            DispatchQueue.main.async {
//                HUD.show(.progress)
//            }
//        }
//
//        ChatsManager.startGroup(with: self.members,
//                                name: name,
//                                startProgressBar: hudShow) { error in
//            DispatchQueue.main.async {
//                if let error = error {
//                    HUD.hide()
//                    self.alert(error)
//                } else {
//                    HUD.flash(.success)
//                    self.popToRoot()
//                }
//            }
//        }
    }

    @IBAction func nameChanged(_ sender: Any) {
        if let name = nameTextField.text, let letter = name.uppercased().first {
            letterLabel.text = String(letter)
            createButton.isEnabled = true
        } else {
            letterLabel.text = ""
            createButton.isEnabled = false
        }
    }

    @IBAction func backgroundTap(_ sender: Any) {
        self.view.endEditing(true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        // FIXME: Error handling/logging
        if let userList = segue.destination as? UsersListViewController,
            let cards = try? self.members.map { try $0.getCard() } {

            userList.users = cards

            let height = userList.tableView.rowHeight
            self.usersListHeight.constant = CGFloat(self.members.count) * height
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard self.createButton.isEnabled else {
            return false
        }

        self.createTapped(self)

        return true
    }
}
