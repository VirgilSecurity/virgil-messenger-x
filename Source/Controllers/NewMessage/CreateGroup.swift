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

    public var members: [Channel] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        nameTextField.delegate = self
    }

    @IBAction func createTapped(_ sender: Any) {
        guard let name = nameTextField.text else {
            return
        }

        guard self.checkReachability() else {
            return
        }

        let hudShow = {
            DispatchQueue.main.async {
                HUD.show(.progress)
            }
        }

        ChatsManager.startGroup(with: self.members,
                                name: name,
                                startProgressBar: hudShow) { error in
            DispatchQueue.main.async {
                if let error = error {
                    HUD.hide()
                    self.alert(error)
                } else {
                    HUD.flash(.success)
                    self.popToRoot()
                }
            }
        }
    }

    @IBAction func nameChanged(_ sender: Any) {
        if let name = nameTextField.text, let letter = name.uppercased().first {
            letterLabel.text = String(letter)
            createButton.isEnabled = true
        } else {
            letterLabel.text = ""
            createButton.isEnabled = true
        }
    }

    @IBAction func backgroundTap(_ sender: Any) {
        self.view.endEditing(true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        // FIXME: Error handling/logging
        if let userList = segue.destination as? UsersListViewController,
            let cards = try? self.members.map { try $0.getCard() }  {

            userList.users = cards

            let height = userList.tableView.rowHeight
            self.usersListHeight.constant = CGFloat(self.members.count) * height
        }
    }
}
