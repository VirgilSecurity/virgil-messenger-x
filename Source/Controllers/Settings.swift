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
    let readReceiptsSwitch: UISwitch = UISwitch(frame: .zero)

    private lazy var cells = [
        [
            Cell(
                identifier: .regular,
                action: openNotificationSettings,
                configure: {
                    $0.textLabel?.text = "Notifications"
                    $0.textLabel?.textColor = .textColor
                }
            ),
            Cell(
                identifier: .regular,
                action: nil,
                configure: {
                    $0.textLabel?.text = "Send Read Receipts"
                    $0.textLabel?.textColor = .textColor
                    $0.selectionStyle = .none
                    $0.accessoryView = self.readReceiptsSwitch
                }
            ),
            Cell(
                identifier: .detail,
                action: nil,
                configure: {
                    $0.textLabel?.text = "Version"
                    $0.textLabel?.textColor = .mutedTextColor
                    $0.detailTextLabel?.textColor = .mutedTextColor
                    $0.isUserInteractionEnabled = false

                    let info = Bundle.main.infoDictionary
                    let appVersion = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
                    let buildNumber = info?["CFBundleVersion"] as? String ?? "Unknown"
                    $0.detailTextLabel?.text = "\(appVersion) (\(buildNumber))"
                }
            )
        ],
        [
            Cell(
                identifier: .regular,
                action: logOut,
                configure: {
                    $0.textLabel?.text = "Logout"
                    $0.textLabel?.textColor = .dangerTextColor
                }
            )
        ],
        [
            Cell(
                identifier: .regular,
                action: deleteAccount,
                configure: {
                    $0.textLabel?.text = "Delete account"
                    $0.textLabel?.textColor = .dangerTextColor
                }
            )
        ]
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        let sendReadReceipts = CoreData.shared.currentAccount?.sendReadReceipts ?? true
        self.readReceiptsSwitch.setOn(sendReadReceipts, animated: false)
        self.readReceiptsSwitch.addTarget(self, action: #selector(self.readReceiptsSwitchChanged), for: .valueChanged)

        Cell.registerCells(in: self.tableView)

        self.tableView.tableFooterView = UIView(frame: .zero)
        self.tableView.delegate = self
        self.tableView.dataSource = self

        let account = try! CoreData.shared.getCurrentAccount()
        self.usernameLabel.text = account.identity

        self.letterLabel.text = String(describing: account.letter)

        self.avatarView.draw(with: account.colors)
    }

    @objc private func readReceiptsSwitchChanged(_ sender: Any) {
        do {
            try CoreData.shared.setSendReadReceipts(to: self.readReceiptsSwitch.isOn)
        }
        catch {
            Log.error(error, message: "Changing sendReadReceipt option failed")
        }
    }

    private func openNotificationSettings() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }

    private func logOut() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        let logoutAction = UIAlertAction(title: "Logout", style: .destructive) { _ in
            UserAuthorizer().logOut { error in
                if let error = error {
                    self.alert(error)
                }

                DispatchQueue.main.async {
                    self.switchNavigationStack(to: .authentication)
                }
            }
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

                self.switchNavigationStack(to: .authentication)
            }
            catch {
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
        cells[indexPath].action?()
    }

    func tableView(_ : UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 10
    }
}

extension SettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return cells.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cells[indexPath].dequeue(from: tableView, for: indexPath)
    }
}

extension SettingsViewController {
    struct Cell {
        enum Identifier: String, CaseIterable {
            case regular
            case detail

            func register(in tableView: UITableView) {
                let type: UITableViewCell.Type
                switch self {
                case .regular:
                    type = UITableViewCell.self
                case .detail:
                    type = DetailTableViewCell.self
                }

                tableView.register(
                    type,
                    forCellReuseIdentifier: self.rawValue
                )
            }
        }

        let identifier: Identifier
        let action: (() -> Void)?
        let configure: ((UITableViewCell) -> Void)

        func dequeue(from tableView: UITableView, for indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: identifier.rawValue,
                for: indexPath
            )

            cell.accessoryType = .none
            cell.backgroundColor = .appThemeBackgroundColor

            let colorView = UIView()
            colorView.backgroundColor = .appThemeForegroundColor
            cell.selectedBackgroundView = colorView

            configure(cell)

            return cell
        }

        static func registerCells(in tableView: UITableView) {
            Identifier.allCases.forEach {
                $0.register(in: tableView)
            }
        }
    }
}
