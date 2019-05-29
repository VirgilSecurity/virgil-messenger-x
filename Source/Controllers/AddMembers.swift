//
//  AddMembers.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 5/6/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit
import PKHUD
import VirgilSDK

class AddMembersViewController: ViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addButton: UIBarButtonItem!

    private var members: [Channel] = [] {
        didSet {
            self.addButton.isEnabled = !self.members.isEmpty
        }
    }

    public var dataSource: DataSource!

    override func viewDidLoad() {
        super.viewDidLoad()

        let chatListCellNib = UINib(nibName: ChooseMembersCell.name, bundle: Bundle.main)
        self.tableView.register(chatListCellNib, forCellReuseIdentifier: ChooseMembersCell.name)

        self.tableView.rowHeight = 60
        self.tableView.tableFooterView = UIView(frame: .zero)
        self.tableView.dataSource = self
    }

    @IBAction func addTapped(_ sender: Any) {
        let cards = self.members.map { $0.cards.first! }

        // FIXME
        for newCard in cards {
            for card in CoreDataHelper.shared.currentChannel!.cards {
                if card.identity == newCard.identity {
                    self.alert(UserFriendlyError.memberAlreadyExists)
                    return
                }
            }
        }

        HUD.show(.progress)

        self.dataSource.addChangeMembersMessage(add: cards).start { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    HUD.hide()
                    self.alert(error)
                } else {
                    HUD.flash(.success)
                    self.navigationController?.popViewController(animated: true)
                }
            }
        }
    }
}

extension AddMembersViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return CoreDataHelper.shared.getSingleChannels().count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChooseMembersCell.name) as! ChooseMembersCell

        let users = CoreDataHelper.shared.getSingleChannels()

        cell.tag = users.count - indexPath.row - 1
        cell.delegate = self

        cell.configure(with: users)

        return cell
    }
}

extension AddMembersViewController: CellTapDelegate {
    func didTapOn(_ cell: UITableViewCell) {
        if let cell = cell as? ChooseMembersCell {
            let channel = CoreDataHelper.shared.getSingleChannels()[cell.tag]

            if cell.isMember {
                self.members.append(channel)
            } else {
                self.members = self.members.filter { $0 != channel }
            }
        }
    }
}

