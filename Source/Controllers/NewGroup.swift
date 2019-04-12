//
//  NewGroup.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/11/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit

class NewGroupViewController: ViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var nextButton: UIBarButtonItem!

    private var members: [String] = [] {
        didSet {
            self.nextButton.isEnabled = !self.members.isEmpty
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let chatListCellNib = UINib(nibName: CheckContactsCell.name, bundle: Bundle.main)
        self.tableView.register(chatListCellNib, forCellReuseIdentifier: CheckContactsCell.name)

        self.tableView.rowHeight = 60
        self.tableView.tableFooterView = UIView(frame: .zero)
        self.tableView.dataSource = self
    }
}

extension NewGroupViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return CoreDataHelper.shared.getChannels().count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CheckContactsCell.name) as! CheckContactsCell

        let channels = CoreDataHelper.shared.getChannels()
        let count = channels.count

        cell.tag = count - indexPath.row - 1
        cell.delegate = self

        guard let channel = channels[safe: cell.tag] else {
            return cell
        }

        cell.usernameLabel.text = channel.name
        cell.letterLabel.text = channel.letter
        cell.avatarView.gradientLayer.colors = [channel.colorPair.first, channel.colorPair.second]
        cell.avatarView.gradientLayer.gradient = GradientPoint.bottomLeftTopRight.draw()

        return cell
    }
}

extension NewGroupViewController: CellTapDelegate {
    func didTapOn(_ cell: UITableViewCell) {
        if let cell = cell as? CheckContactsCell, let username = cell.usernameLabel.text {

            if cell.isMember {
                self.members.append(username)
            } else {
                self.members = self.members.filter { $0 != username }
            }
        }
    }
}
