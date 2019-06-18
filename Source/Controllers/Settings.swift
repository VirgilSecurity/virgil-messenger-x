//
//  SettingsViewController.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 11/22/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit

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

        let account = CoreDataHelper.shared.currentAccount!
        self.usernameLabel.text = account.identity

        self.letterLabel.text = String(describing: account.letter)

        self.avatarView.gradientLayer.colors = [account.colorPair.first, account.colorPair.second]
        self.avatarView.gradientLayer.gradient = GradientPoint.bottomLeftTopRight.draw()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    private func logOut() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        let logoutAction = UIAlertAction(title: "Logout", style: .destructive) { _ in
            UserAuthorizer().logOut()

            self.switchNavigationStack(to: AuthenticationViewController.name)
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alert.addAction(logoutAction)
        alert.addAction(cancelAction)

        self.present(alert, animated: true)
    }

    private func deleteAccount() {
        let alertController = UIAlertController(title: "Delete account",
                                                message: "Account data will be removed from this device. People still will be able to write to you. This nickname cannot be used for registration again.",
                                                preferredStyle: .alert)

        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            do {
                try UserAuthorizer().deleteAccount()

                self.switchNavigationStack(to: AuthenticationViewController.name)
            } catch {
                self.alert(error)
            }
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alertController.addAction(okAction)
        alertController.addAction(cancelAction)

        self.present(alertController, animated: true)
    }
}

extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch indexPath.section {
        case 0:
            self.performSegue(withIdentifier: "About", sender: self)
        case 1:
            self.logOut()
        case 2:
            self.deleteAccount()
        default:
            fatalError("Unknown number of table view section")
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
