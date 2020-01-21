//
//  ChatListCell.swift
//  Morse
//
//  Created by Oleksandr Deundiak on 10/18/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit

class ChatListCell: UITableViewCell {
    static let name = "ChatListCell"

    weak var delegate: CellTapDelegate?

    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var lastMessageLabel: UILabel!
    @IBOutlet weak var lastMessageDateLabel: UILabel!
    @IBOutlet weak var avatarView: GradientView!
    @IBOutlet weak var letterLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        self.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.didTap)))
    }

    @objc func didTap() {
        self.delegate?.didTapOn(self)
    }

    public func configure(with channels: [Channel]) {
        guard let channel = channels[safe: self.tag] else {
            return
        }

        self.usernameLabel.text = channel.name
        self.letterLabel.text = channel.letter
        self.avatarView.draw(with: channel.colors)

        self.lastMessageLabel.text = channel.lastMessagesBody
        self.lastMessageDateLabel.text = channel.lastMessagesDate?.shortString() ?? ""
    }
}
