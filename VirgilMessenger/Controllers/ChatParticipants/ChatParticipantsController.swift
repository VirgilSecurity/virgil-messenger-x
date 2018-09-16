//
//  ChatParticipantsController.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 6/4/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import UIKit
import PKHUD

class ChatParticipantsController: ViewController {
    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.navigationItem.title = "Members"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self,
                                                                 action: #selector(self.didTapAdd(_:)))
    }

    @objc func didTapAdd(_ sender: Any) {
        guard currentReachabilityStatus != .notReachable else {
            let controller = UIAlertController(title: nil, message: "Please check your network connection", preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(controller, animated: true)

            return
        }

        let alertController = UIAlertController(title: "Add", message: "Enter username", preferredStyle: .alert)

        alertController.addTextField(configurationHandler: {
            $0.placeholder = "Username"
            $0.delegate = self
            $0.keyboardAppearance = UIKeyboardAppearance.dark
        })

        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            guard let username = alertController.textFields?.first?.text else {
                return
            }
            self.addMember(username)
        }))

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in }))

        self.present(alertController, animated: true)
    }

    private func addMember(_ username: String) {
        let username = username.lowercased()

        guard username != TwilioHelper.sharedInstance.username else {
            self.alert("You need to communicate with other people :)")
            return
        }

        guard let currentChannel = CoreDataHelper.sharedInstance.currentChannel else {
            Log.error("Missing current channel")
            return
        }

        if (currentChannel.cards.contains {
            VirgilHelper.sharedInstance.buildCard($0)?.identity == username
        }) {
            self.alert("This user is already member of channel")
        } else {
            HUD.show(.progress)
            VirgilHelper.sharedInstance.getExportedCard(identity: username) { exportedCard, error in
                guard error == nil, let exportedCard = exportedCard else {
                    HUD.flash(.error)
                    return
                }
                if let title = CoreDataHelper.sharedInstance.currentChannel?.name {
                    TwilioHelper.sharedInstance.setChannel(withName: title)
                }
                TwilioHelper.sharedInstance.invite(member: username) { error in
                    if error == nil {
                        CoreDataHelper.sharedInstance.addMember(card: exportedCard)
                        guard let cards = CoreDataHelper.sharedInstance.currentChannel?.cards else {
                            Log.error("Can't fetch Core Data Cards. Card was not added to encrypt for")
                            HUD.flash(.error)
                            return
                        }
                        VirgilHelper.sharedInstance.setChannelKeys(cards)
                        HUD.flash(.success)
                        HUD.flash(.success)
                        defer { self.tableView.reloadData() }
                    } else {
                        HUD.flash(.error)
                    }
                }
            }
        }
    }

    @IBAction func closeTapped(_ sender: Any) {
        DispatchQueue.main.async {
            self.dismiss(animated: true)
        }
    }
}

extension ChatParticipantsController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let cards = CoreDataHelper.sharedInstance.currentChannel?.cards else {
            Log.error("Can't form row: missing Core Data cards")
            return 0
        }
        return cards.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChatParticipantCell.name) as! ChatParticipantCell

        guard let cards = CoreDataHelper.sharedInstance.currentChannel?.cards,
            let exportedCard = cards[safe: cards.count - indexPath.row - 1],
            let card = VirgilHelper.sharedInstance.buildCard(exportedCard) else {
                return cell
        }
        cell.participantLabel.text = card.identity

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return 50
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
}
