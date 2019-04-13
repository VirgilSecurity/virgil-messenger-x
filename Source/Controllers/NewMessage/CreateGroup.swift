//
//  CreateGroup.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/12/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit

class CreateGroupViewController: ViewController {
    @IBOutlet weak var letterLabel: UILabel!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var createButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        nameTextField.delegate = self
    }

    @IBAction func createTapped(_ sender: Any) {
        self.navigationController?.popToRootViewController(animated: true)
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
