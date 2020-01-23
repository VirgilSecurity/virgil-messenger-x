//
//  ChooseMembersCell.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/11/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit
import BEMCheckBox

class ChooseMembersCell: UITableViewCell, BEMCheckBoxDelegate {
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
        self.radioButton.delegate = self

        self.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                                     action: #selector(self.didTapOnRow)))
    }

    func didTap(_ checkBox: BEMCheckBox) {
        self.delegate?.didTapOn(self)
    }

    @objc func didTapOnRow() {
        self.switchMembership()

        self.delegate?.didTapOn(self)
    }

    private func switchMembership() {
        self.radioButton.setOn(!self.isMember, animated: true)
    }

    public func configure(with users: [Channel], selected: [Channel]) {
        guard let user = users[safe: self.tag] else {
            return
        }

        let isSelected = selected.contains(user)

        self.radioButton.setOn(isSelected, animated: true)
        self.usernameLabel.text = user.name
        self.letterLabel.text = user.letter
        self.avatarView.draw(with: user.colors)
    }
}
