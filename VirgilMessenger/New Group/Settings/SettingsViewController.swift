//
//  SettingsViewController.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 11/22/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

class SettingsViewController: ViewController {
    @IBOutlet weak var avatarView: GradientView!
    @IBOutlet weak var letterLabel: UILabel!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        self.tableView.tableFooterView = UIView(frame: .zero)
        self.tableView.delegate = self
        self.tableView.dataSource = self

        self.tableView.backgroundColor = UIColor(rgb: 0x2B303B)
        self.view.backgroundColor = UIColor(rgb: 0x2B303B)

        self.usernameLabel.text = TwilioHelper.sharedInstance.username

        let up = TwilioHelper.sharedInstance.username.uppercased().first!
        self.letterLabel.text = String(describing: up)

        if let account = CoreDataHelper.sharedInstance.currentAccount {
            let num = Int(account.numColorPair)
            let f = UIConstants.colorPairs[num].first
            let s = UIConstants.colorPairs[num].second
            self.avatarView.gradientLayer.colors = [f, s]
            self.avatarView.gradientLayer.gradient = GradientPoint.bottomLeftTopRight.draw()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

}

extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0 {
           self.performSegue(withIdentifier: "About", sender: self)
        } else if indexPath.section == 1 {
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Logout", style: .destructive) { _ in
                UserDefaults.standard.set(nil, forKey: "last_username")

                let vc = UIStoryboard(name: "Authentication", bundle: Bundle.main).instantiateInitialViewController() as! UINavigationController

                self.switchNavigationStack(to: vc)
            })

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

            self.present(alert, animated: true)
        } else if indexPath.section == 2 {
            let alertController = UIAlertController(title: "Delete account",
                                                    message: "Account data will be removed from this device. People still will be able to write to you. This nickname cannot be used for registration again.",
                                                    preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                UserDefaults.standard.set(nil, forKey: "last_username")

                CoreDataHelper.sharedInstance.deleteAccount()
                VirgilHelper.sharedInstance.deleteStorageEntry(entry: TwilioHelper.sharedInstance.username)

                let vc = UIStoryboard(name: "Authentication", bundle: Bundle.main).instantiateInitialViewController() as! UINavigationController

                self.switchNavigationStack(to: vc)
            }))

            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in }))

            self.present(alertController, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = UIColor(rgb: 0x20232B)
    }

    func tableView(_ : UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 10
    }
}

extension SettingsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let colorView = UIView()
        colorView.backgroundColor = UIColor(rgb: 0x2B303B)
        cell.selectedBackgroundView = colorView

        if indexPath.section == 0 {
            cell.textLabel?.text = "About"
            cell.textLabel?.textColor = UIColor(rgb: 0xC7C7CC)
            cell.accessoryType = .disclosureIndicator
        } else if indexPath.section == 1 {
            cell.textLabel?.text = "Logout"
            cell.textLabel?.textColor = UIColor(rgb: 0x9E3621)
            cell.accessoryType = .none
        } else if indexPath.section == 2 {
            cell.textLabel?.text = "Delete account"
            cell.textLabel?.textColor = UIColor(rgb: 0x9E3621)
            cell.accessoryType = .none
        }

        return cell
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
}
