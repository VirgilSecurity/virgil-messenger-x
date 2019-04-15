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

    private var selectedChannelMessagesCount: Int = 0

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if let userList = segue.destination as? UsersListViewController {

            userList.users = self.users
            userList.cellTapDelegate = self

            let height = userList.tableView.rowHeight
            self.usersListHeight.constant = CGFloat(self.users.count) * height

        } else if let chatController = segue.destination as? ChatViewController {
            let pageSize = ChatConstants.chatPageSize

            let dataSource = DataSource(count: self.selectedChannelMessagesCount, pageSize: pageSize)
            chatController.dataSource = dataSource
            chatController.messageSender = dataSource.messageSender
        }
    }
}

extension NewMessageViewController: CellTapDelegate {
    func didTapOn(_ cell: UITableViewCell) {
        if let _ = cell as? UsersListCell {
            guard let user = self.users[safe: cell.tag],
                let name = user.name,
                let count = user.message?.count else {
                    return
            }

            TwilioHelper.shared.setChannel(withName: name)
            CoreDataHelper.shared.setCurrent(channel: user)
            VirgilHelper.shared.setChannelCards(user.cards)

            self.selectedChannelMessagesCount = count

            self.performSegue(withIdentifier: "goToChat", sender: self)
        }
    }
}
