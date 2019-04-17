//
//  NewMessage.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/15/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit

class NewMessageViewController: ViewController {
    @IBOutlet weak var usersListHeight: NSLayoutConstraint!

    private let users: [Channel] = CoreDataHelper.shared.getSingleChannels()

    private var selectedUser: Channel?

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if let userList = segue.destination as? UsersListViewController {

            userList.users = self.users
            userList.cellTapDelegate = self

            let height = userList.tableView.rowHeight
            self.usersListHeight.constant = CGFloat(self.users.count) * height

        } else if let chatController = segue.destination as? ChatViewController,
            let channel = self.selectedUser {
                chatController.dataSource = DataSource(count: channel.messages.count)
                chatController.channel = channel
        }
    }
}

extension NewMessageViewController: CellTapDelegate {
    func didTapOn(_ cell: UITableViewCell) {
        if let _ = cell as? UsersListCell {
            guard let user = self.users[safe: cell.tag] else {
                return
            }

            self.selectedUser = user

            self.performSegue(withIdentifier: "goToChat", sender: self)
        }
    }
}
