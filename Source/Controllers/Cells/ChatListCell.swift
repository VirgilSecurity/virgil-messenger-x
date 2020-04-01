//
//  ChatListCell.swift
//  VirgilMessenger
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
    @IBOutlet weak var unreadCountLabel: UILabel!
    @IBOutlet weak var unreadCountView: UIView!
    @IBOutlet weak var unreadCountViewWidth: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.didTap))
        self.contentView.addGestureRecognizer(tapRecognizer)
    }

    @objc func didTap() {
        self.delegate?.didTapOn(self)
    }

    public func configure(with channels: [Storage.Channel]) {
        guard let channel = channels[safe: self.tag] else {
            return
        }

        self.usernameLabel.text = channel.name
        self.letterLabel.text = channel.letter
        self.avatarView.draw(with: channel.colors)

        self.lastMessageLabel.text = channel.lastMessagesBody
        self.lastMessageDateLabel.text = channel.lastMessagesDate?.shortString() ?? ""

        self.configureUnreadLabel(with: channel.unreadCount)
    }
    
    private func configureUnreadLabel(with unreadCount: Int16) {
        if unreadCount > 0 {
            let text = unreadCount > 999 ? "999" : String(unreadCount)
                        
            self.unreadCountLabel.text = text
            self.unreadCountViewWidth.constant = CGFloat(15 + 7 * text.count)
            self.unreadCountView.isHidden = false
        }
        else {
            self.unreadCountView.isHidden = true
        }
    }
}
