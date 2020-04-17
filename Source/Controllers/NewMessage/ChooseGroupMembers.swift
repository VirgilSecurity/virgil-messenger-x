//
//  ChooseGroupMembers.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/11/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit

class ChooseMembersViewController: ViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var nextButton: UIBarButtonItem!
    @IBOutlet weak var noContactsView: UIView!

    private let channels = Storage.shared.getSingleChannels()

    private var members: [Storage.Channel] = [] {
        didSet {
            self.nextButton.isEnabled = !self.members.isEmpty
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let chatListCellNib = UINib(nibName: ChooseMembersCell.name, bundle: Bundle.main)
        self.tableView.register(chatListCellNib, forCellReuseIdentifier: ChooseMembersCell.name)

        self.tableView.rowHeight = 60
        self.tableView.tableFooterView = UIView(frame: .zero)
        self.tableView.dataSource = self

        self.noContactsView.isHidden = !self.channels.isEmpty
    }

    @IBAction func nextTapped(_ sender: Any) {
        self.performSegue(withIdentifier: "goToNewGroup", sender: self)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if let сontroller = segue.destination as? CreateGroupViewController {
            сontroller.members = self.members
        }
    }
}

extension ChooseMembersViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.channels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChooseMembersCell.name) as! ChooseMembersCell

        cell.tag = indexPath.row
        cell.delegate = self

        cell.configure(with: self.channels, selected: self.members)

        return cell
    }
}

extension ChooseMembersViewController: CellTapDelegate {
    func didTapOn(_ cell: UITableViewCell) {
        if let cell = cell as? ChooseMembersCell {
            let channel = self.channels[cell.tag]

            if cell.isMember {
                self.members.append(channel)
            }
            else {
                self.members = self.members.filter { $0 != channel }
            }
        }
    }
}
