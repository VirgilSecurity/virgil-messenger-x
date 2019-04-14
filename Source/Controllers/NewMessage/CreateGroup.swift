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

    public var members: [Channel] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        nameTextField.delegate = self
    }

    @IBAction func createTapped(_ sender: Any) {
        guard let name = nameTextField.text else {
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
                    self.navigationController?.popToRootViewController(animated: true)
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
}
