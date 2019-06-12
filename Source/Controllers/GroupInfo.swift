//
//  GroupInfo.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/18/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit
import PKHUD

class GroupInfoViewController: ViewController {
    @IBOutlet weak var avatarView: GradientView!
    @IBOutlet weak var letterLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var usersListHeight: NSLayoutConstraint!
    
    public var channel: Channel!
    public var dataSource: DataSource!

    private var usersListController: UsersListViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.letterLabel.text = String(describing: self.channel.letter)
        self.nameLabel.text = self.channel.name

        self.avatarView.gradientLayer.colors = [self.channel.colorPair.first, self.channel.colorPair.second]
        self.avatarView.gradientLayer.gradient = GradientPoint.bottomLeftTopRight.draw()
    }

    override func viewWillAppear(_ animated: Bool) {
        self.updateUserList()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if let userList = segue.destination as? UsersListViewController {
            self.usersListController = userList
            self.updateUserList()

        } else if let addMembers = segue.destination as? AddMembersViewController {
            addMembers.dataSource = self.dataSource
        }
    }

    private func updateUserList() {
        if let userList = self.usersListController {
            userList.deleteItemDelegate = self.channel.cards.count > 1 ? self : nil

            let members = self.channel.cards.map { CoreDataHelper.shared.getSingleChannel(with: $0.identity)! }

            userList.users = members
            userList.tableView.reloadData()

            let height = userList.tableView.rowHeight
            self.usersListHeight.constant = CGFloat(self.channel.cards.count) * height
        }
    }

    @IBAction func addMemberTapped(_ sender: Any) {
        self.performSegue(withIdentifier: "goToAddMembers", sender: self)
    }
}

extension GroupInfoViewController: DeleteItemDelegate {
    func delete(_ user: Channel) {
        HUD.show(.progress)

        ChatsManager.removeMember(user.cards.first!, dataSource: self.dataSource).start { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    HUD.hide()
                    self.alert(error)
                } else {
                    HUD.flash(.success)
                    self.updateUserList()
                }
            }
        }
    }
}
