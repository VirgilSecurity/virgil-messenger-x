//
//  ChatInfo.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 5/13/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import UIKit

class ChatInfoViewController: ViewController {
    @IBOutlet weak var avatarLabel: UILabel!
    @IBOutlet weak var avatarView: GradientView!
    @IBOutlet weak var usernameLabel: UILabel!

    var channel: Storage.Channel!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.avatarLabel.text = self.channel.letter
        self.avatarView.draw(with: self.channel.colors)
        self.usernameLabel.text = self.channel.name
    }

    @IBAction func startCallTapped(_ sender: Any) {
        CallManager.shared.startOutgoingCall(to: self.channel.name)
    }

    @IBAction func messageTapped(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
}
