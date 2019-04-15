//
//  UsersListCell.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/15/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit

class UsersListCell: UITableViewCell {
    static let name = "UsersListCell"

    weak var delegate: CellTapDelegate?

    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var letterLabel: UILabel!
    @IBOutlet weak var avatarView: GradientView!

    override func awakeFromNib() {
        super.awakeFromNib()
        self.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.didTap)))
    }

    @objc func didTap() {
        self.delegate?.didTapOn(self)
    }

    public func configure(with users: [Channel]) {
        guard let user = users[safe: self.tag] else {
            return
        }

        self.usernameLabel.text = user.name
        self.letterLabel.text = user.letter
        self.avatarView.gradientLayer.colors = [user.colorPair.first, user.colorPair.second]
        self.avatarView.gradientLayer.gradient = GradientPoint.bottomLeftTopRight.draw()
    }
}
