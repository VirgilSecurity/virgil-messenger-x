//
//  ChatListViewController.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/18/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation
import UIKit
import PKHUD
import TwilioChatClient

class ChatListViewController: ViewController {
    @IBOutlet weak var noChatsView: UIView!
    @IBOutlet weak var tableView: UITableView!

    static let name = "ChatList"

    private var currentChannelMessegesCount: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.isUserInteractionEnabled = false
        let indicator = UIActivityIndicatorView()
        indicator.hidesWhenStopped = false
        indicator.startAnimating()

        let titleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))
        titleLabel.textColor = .white
        titleLabel.text = "Updating"
        let titleView = UIStackView(arrangedSubviews: [indicator, titleLabel])
        titleView.spacing = 5

        self.navigationItem.titleView = titleView
        self.configure {
            self.navigationItem.titleView = nil
            self.title = "Chats"
            self.view.isUserInteractionEnabled = true
            indicator.stopAnimating()
        }

        self.tableView.register(UINib(nibName: ChatListCell.name, bundle: Bundle.main),
                                forCellReuseIdentifier: ChatListCell.name)
        self.tableView.rowHeight = 94
        self.tableView.tableFooterView = UIView(frame: .zero)
        self.tableView.backgroundColor = UIColor(rgb: 0x2B303B)
        self.tableView.dataSource = self

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ChatListViewController.reloadTableView(notification:)),
                                               name: Notification.Name(rawValue: TwilioHelper.Notifications.ChannelAdded.rawValue),
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ChatListViewController.reloadTableView(notification:)),
                                               name: Notification.Name(rawValue: TwilioHelper.Notifications.MessageAdded.rawValue),
                                               object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        TwilioHelper.shared.deselectChannel()
        noChatsView.isHidden = TwilioHelper.shared.channels.subscribedChannels().isEmpty ? false : true
        self.tableView.reloadData()
    }

    @objc private func reloadTableView(notification: Notification) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.noChatsView.isHidden = true
        }
    }

    private func configure(completion: @escaping () -> ()) {
        let channels = TwilioHelper.shared.channels.subscribedChannels()
        let group = DispatchGroup()

        for i in 0..<channels.count {
            let channel = channels[i]
            guard let channelName = TwilioHelper.shared.getName(of: channel) else {
                continue
            }

            if let coreChannel = CoreDataHelper.shared.getChannel(withName: channelName) {
                while channel.messages == nil { sleep(1) }

                group.enter()
                self.setLastMessages(twilioChannel: channel, coreChannel: coreChannel) {
                    group.leave()
                }

                group.enter()
                self.updateGroupChannelMembers(twilioChannel: channel, coreChannel: coreChannel) {
                    group.leave()
                }
            } else {
                Log.error("Get Channel failed")
            }
        }

        group.notify(queue: .main) {
            self.tableView.reloadData()
            completion()
        }
    }

    private func setLastMessages(twilioChannel: TCHChannel, coreChannel: Channel, completion: @escaping () -> ()) {
//        if let messages = twilioChannel.messages {
            CoreDataHelper.shared.setLastMessage(for: coreChannel)
            completion()
            // TwilioHelper.shared.setLastMessage(of: messages, channel: coreChannel, completion: completion)
//        } else {
//            Log.error("Get Messages failed")
//            completion()
//        }
    }

    private func updateGroupChannelMembers(twilioChannel: TCHChannel, coreChannel: Channel, completion: @escaping () -> ()) {
        if coreChannel.type == ChannelType.group.rawValue {
            TwilioHelper.shared.updateMembers(of: twilioChannel, coreChannel: coreChannel) {
                completion()
            }
        } else {
            completion()
        }
    }

    @IBAction func noChatsTap(_ sender: Any) {
        self.didTapAdd(self)
    }

    @IBAction func didTapAdd(_ sender: Any) {
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
            guard let username = alertController.textFields?.first?.text, !username.isEmpty else {
                return
            }
            self.addChat(withUsername: username)
        }))

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in }))

        self.present(alertController, animated: true)
    }

    private func addChat(withUsername username: String) {
        guard currentReachabilityStatus != .notReachable else {
            let controller = UIAlertController(title: nil, message: "Please check your network connection", preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(controller, animated: true)

            return
        }

        let username = username.lowercased()

        guard username != TwilioHelper.shared.username else {
            self.alert("You need to communicate with other people :)")
            return
        }

        if (CoreDataHelper.shared.getChannels().contains {
            ($0 as! Channel).name == username
        }) {
            self.alert("You already have this channel")
        } else {
            HUD.show(.progress)
            VirgilHelper.shared.getExportedCard(identity: username) { exportedCard, error in
                guard let exportedCard = exportedCard, error == nil else {
                    Log.error("Getting card failed")
                    self.alert("User not found")
                    HUD.hide()
                    return
                }
                TwilioHelper.shared.createSingleChannel(with: username) { error in
                    if error == nil {
                        _ = CoreDataHelper.shared.createChannel(type: .single,
                                                                        name: username,
                                                                        cards: [exportedCard])
                        self.noChatsView.isHidden = true
                        self.tableView.reloadData()
                        
                        HUD.flash(.success)
                    } else {
                        self.alert("Something went wrong")
                        HUD.hide()
                    }
                }
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension ChatListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChatListCell.name) as! ChatListCell

        let channels = CoreDataHelper.shared.getChannels()
        let count = channels.count

        cell.tag = count - indexPath.row - 1
        cell.delegate = self

        guard let channel = channels[safe: count - indexPath.row - 1] as? Channel else {
            Log.error("Can't form row: Core Data channel wrong index")
            return cell
        }
        cell.usernameLabel.text = channel.name
        cell.letterLabel.text = channel.letter
        cell.avatarView.gradientLayer.colors = [channel.colorPair.first, channel.colorPair.second]
        cell.avatarView.gradientLayer.gradient = GradientPoint.bottomLeftTopRight.draw()

        cell.lastMessageLabel.text = channel.lastMessagesBody
        cell.lastMessageDateLabel.text = channel.lastMessagesDate != nil ? calcDateString(messageDate: channel.lastMessagesDate!) : ""

        return cell
    }

    private func calcDateString(messageDate: Date) -> String {

        let dateFormatter = DateFormatter()
        if messageDate.minutes(from: Date()) < 2 {
            return "now"
        } else if messageDate.days(from: Date()) < 1 {
            dateFormatter.dateStyle = DateFormatter.Style.none
            dateFormatter.timeStyle = DateFormatter.Style.short
        } else {
            dateFormatter.dateStyle = DateFormatter.Style.short
            dateFormatter.timeStyle = DateFormatter.Style.none
        }

        let messageDateString = dateFormatter.string(from: messageDate)

        return messageDateString
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let account = CoreDataHelper.shared.currentAccount,
              let channels = account.channel else {
                Log.error("Can't form row: Core Data account or channels corrupted")
                return 0
        }
        return channels.count
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = UIColor(rgb: 0x2B303B)
    }
}

extension ChatListViewController: CellTapDelegate {
    func didTapOn(_ cell: UITableViewCell) {
        if let username = (cell as! ChatListCell).usernameLabel.text {
            TwilioHelper.shared.setChannel(withName: username)
            self.view.isUserInteractionEnabled = false

            guard CoreDataHelper.shared.loadChannel(withName: username),
                let channel = CoreDataHelper.shared.currentChannel else {
                    Log.error("Channel do not exist in Core Data")
                    return
            }

            // FIXME
            VirgilHelper.shared.setChannelCard(channel.cards.first!)

            TwilioHelper.shared.currentChannel.getMessagesCount { result, count in
                guard result.isSuccessful() else {
                    Log.error("Can't get Twilio messages count")
                    return
                }
                self.currentChannelMessegesCount = Int(count)
                DispatchQueue.main.async {
                    defer { self.view.isUserInteractionEnabled = true }
                    self.performSegue(withIdentifier: "goToChat", sender: self)
                }
            }
        }
    }


    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if let chatController = segue.destination as? ChatViewController {
            let pageSize = ChatConstants.chatPageSize

            let dataSource = DataSource(count: self.currentChannelMessegesCount, pageSize: pageSize)
            chatController.dataSource = dataSource
            chatController.messageSender = dataSource.messageSender
        }
    }
}
