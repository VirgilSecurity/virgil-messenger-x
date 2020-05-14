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
    @IBOutlet weak var tableView: UITableView!

    var channel: Storage.Channel!

    private lazy var cells = [
        [
            Cell(
                identifier: .regular,
                action: self.blockingCellTapped,
                configure: {
                    if self.channel.blocked {
                        $0.textLabel?.text = "Unblock User"
                        $0.textLabel?.textColor = .textColor
                    }
                    else {
                        $0.textLabel?.text = "Block User"
                        $0.textLabel?.textColor = .dangerTextColor
                    }
                }
            )
        ]
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        self.avatarLabel.text = self.channel.letter
        self.avatarView.draw(with: self.channel.colors)
        self.usernameLabel.text = self.channel.name

        Cell.registerCells(in: self.tableView)

        self.tableView.tableFooterView = UIView(frame: .zero)
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }

    @IBAction func startCallTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
        CallManager.shared.startOutgoingCall(to: self.channel.name)
    }

    @IBAction func messageTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }

    func blockingCellTapped() {
        self.channel.blocked ? self.unblockTapped() : self.blockTapped()
    }

    func blockTapped() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        let blockAction = UIAlertAction(title: "Block user", style: .destructive) { _ in
            // FIXME
            try! Storage.shared.block(channel: self.channel)

            self.tableView.reloadData()
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alert.addAction(blockAction)
        alert.addAction(cancelAction)

        self.present(alert, animated: true)
    }

    func unblockTapped() {
        // FIXME
        try! Storage.shared.unblock(channel: self.channel)

        self.tableView.reloadData()
    }
}

extension ChatInfoViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        cells[indexPath].action?()
    }
}

extension ChatInfoViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return cells.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cells[indexPath].dequeue(from: tableView, for: indexPath)
    }
}
