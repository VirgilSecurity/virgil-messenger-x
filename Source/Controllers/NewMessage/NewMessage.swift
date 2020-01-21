//
//  NewMessage.swift
//  Morse
//
//  Created by Yevhen Pyvovarov on 4/15/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit

class NewMessageViewController: ViewController {
    @IBOutlet weak var usersListHeight: NSLayoutConstraint!

    private let users: [Channel] = CoreData.shared.getSingleChannels()

    private var selectedUser: Channel?

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        // FIXME: Error handling/logging
        if let userList = segue.destination as? UsersListViewController,
            let cards = try? self.users.map { try $0.getCard() } {

            userList.users = cards
            userList.cellTapDelegate = self

            let height = userList.tableView.rowHeight
            self.usersListHeight.constant = CGFloat(self.users.count) * height

        }
        else if let chatController = segue.destination as? ChatViewController,
            let channel = self.selectedUser {
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
