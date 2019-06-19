//
//  ChooseMembersCell.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/11/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit
import BEMCheckBox

class ChooseMembersCell: UITableViewCell {
    static let name = "ChooseMembersCell"

    weak var delegate: CellTapDelegate?

    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var letterLabel: UILabel!
    @IBOutlet weak var avatarView: GradientView!
    @IBOutlet weak var radioButton: BEMCheckBox!

    public var isMember: Bool {
        return self.radioButton.on
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        self.radioButton.onAnimationType = .fill
        self.radioButton.offAnimationType = .fill
        self.radioButton.animationDuration = 0.1
        self.radioButton.lineWidth = 1.1
        self.radioButton.onFillColor = .white
        self.radioButton.onTintColor = .black
        self.radioButton.onCheckColor = .black

        self.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                                     action: #selector(self.didTap)))
    }

    @objc func didTap() {
        self.switchMembership()

        self.delegate?.didTapOn(self)
    }

    private func switchMembership() {
        self.radioButton.setOn(!self.isMember, animated: true)
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
