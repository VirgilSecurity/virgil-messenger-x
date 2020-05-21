//
//  NewMessageTableViewController.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/11/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit
import PKHUD

class NewMessageTableViewController: UITableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard self.checkReachability() else {
            return
        }

        if indexPath.row == 0 {
            self.performSegue(withIdentifier: "goToNewGroup", sender: self)
        }
        else if indexPath.row == 1 {
            self.addContact()
        }
    }

    private func addContact() {
        // FIXME
        fatalError("DISABLED")
//
//        let alert = UIAlertController(title: "Add", message: "Enter username", preferredStyle: .alert)
//
//        alert.addTextField {
//            $0.placeholder = "Username"
//            $0.delegate = self
//            $0.keyboardAppearance = .dark
//        }
//
//        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
//            guard let username = alert.textFields?.first?.text, !username.isEmpty else {
//                return
//            }
//
//            guard self.checkReachability() else {
//                return
//            }
//
//            let hudShow = {
//                DispatchQueue.main.async {
//                    HUD.show(.progress)
//                }
//            }
//
//            ChatsManager.startSingle(with: username, startProgressBar: hudShow) { error in
//                DispatchQueue.main.async {
//                    if let error = error {
//                        HUD.hide()
//                        self.alert(error)
//                    }
//                    else {
//                        HUD.flash(.success)
//                        self.navigationController?.popViewController(animated: true)
//                    }
//                }
//            }
//        }
//
//        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
//
//        alert.addAction(okAction)
//        alert.addAction(cancelAction)
//
//        self.present(alert, animated: true)
    }
}
