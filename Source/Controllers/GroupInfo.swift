//
//  GroupInfo.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/18/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit
import PKHUD
import VirgilSDK

class GroupInfoViewController: ViewController {
    @IBOutlet weak var avatarView: GradientView!
    @IBOutlet weak var letterLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var usersListHeight: NSLayoutConstraint!
    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var scrollView: UIScrollView!
    
    public var channel: Channel!
    public var dataSource: DataSource!

    private var usersListController: UsersListViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.letterLabel.text = String(describing: self.channel.letter)
        self.nameLabel.text = self.channel.name
        self.avatarView.draw(with: self.channel.colors)

        let isEnabled = self.channel.initiator == Twilio.shared.identity
        self.addButton.isEnabled = isEnabled

        if !isEnabled {
            self.addButton.tintColor = UIColor.clear
        }

        self.setupObservers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.updateUserList()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.updateScrollViewContentSize()
    }

    private func setupObservers() {
        let popToRoot: Notifications.Block = { [weak self] _ in
            DispatchQueue.main.async {
                self?.popToRoot()
            }
        }

        let processMessage: Notifications.Block = { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateUserList()
            }
        }

        Notifications.observe(for: .currentChannelDeleted, block: popToRoot)
        Notifications.observe(for: .messageAddedToCurrentChannel, block: processMessage)
    }

    private func updateScrollViewContentSize() {
        let bounds = UIScreen.main.bounds

        // FIXME
        let height = max(self.usersListHeight.constant + 170, bounds.height)

        self.scrollView.contentSize = CGSize(width: bounds.width, height: height)
    }


    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if let userList = segue.destination as? UsersListViewController {
            self.usersListController = userList
            self.updateUserList()
        }
        else if let addMembers = segue.destination as? AddMembersViewController {
            addMembers.dataSource = self.dataSource
        }
    }

    private func updateUserList() {
        if let userList = self.usersListController {
            userList.deleteItemDelegate = self.channel.cards.count > 1 ? self : nil

            userList.users = self.channel.cards
            userList.admin = self.channel.initiator
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
    func delete(_ user: Card) {
        guard self.checkReachability(), Configurator.isUpdated else {
            return
        }
        
        HUD.show(.progress)

        ChatsManager.removeMember(user.identity, dataSource: self.dataSource).start { _, error in
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
