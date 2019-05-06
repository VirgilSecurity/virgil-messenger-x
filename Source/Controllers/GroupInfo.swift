//
//  GroupInfo.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/18/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit

class GroupInfoViewController: ViewController {
    @IBOutlet weak var avatarView: GradientView!
    @IBOutlet weak var letterLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var usersListHeight: NSLayoutConstraint!
    
    public var channel: Channel!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.letterLabel.text = String(describing: self.channel.letter)
        self.nameLabel.text = self.channel.name

        self.avatarView.gradientLayer.colors = [self.channel.colorPair.first, self.channel.colorPair.second]
        self.avatarView.gradientLayer.gradient = GradientPoint.bottomLeftTopRight.draw()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if let userList = segue.destination as? UsersListViewController {
            let members = self.channel.cards.map { CoreDataHelper.shared.getSingleChannel(with: $0.identity)! }

            userList.users = members

            let height = userList.tableView.rowHeight
            self.usersListHeight.constant = CGFloat(self.channel.cards.count) * height
        }
    }

    @IBAction func addMemberTapped(_ sender: Any) {
        self.performSegue(withIdentifier: "goToAddMembers", sender: self)
    }
}
