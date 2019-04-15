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

    private var members: [Channel] = [] {
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

extension ChooseMembersViewController: CellTapDelegate {
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
