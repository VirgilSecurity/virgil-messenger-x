//
//  ChatListViewController.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/18/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit
import PKHUD

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

        Configurator.configure { error in
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.navigationItem.titleView = nil
                self.title = "Chats"
                self.view.isUserInteractionEnabled = true
                indicator.stopAnimating()
            }
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
        // FIXME
//        TwilioHelper.shared.deselectChannel()
        noChatsView.isHidden = CoreDataHelper.shared.currentAccount?.channel?.count ?? 0 > 0 ? true : false
        self.tableView.reloadData()
    }

    @objc private func reloadTableView(notification: Notification) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.noChatsView.isHidden = true
        }
    }

    @IBAction func noChatsTap(_ sender: Any) {
        self.didTapAdd(self)
    }

    @IBAction func didTapAdd(_ sender: Any) {
        guard self.checkReachability() else {
            return
        }

        let alert = UIAlertController(title: "Add", message: "Enter username", preferredStyle: .alert)

        alert.addTextField {
            $0.placeholder = "Username"
            $0.delegate = self
            $0.keyboardAppearance = .dark
        }

        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            guard let username = alert.textFields?.first?.text, !username.isEmpty else {
                return
            }

            guard self.checkReachability() else {
                return
            }

            let hudShow = {
                DispatchQueue.main.async {
                    HUD.show(.progress)
                }
            }

            ChatsManager.addChat(with: username, startProgressBar: hudShow) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        HUD.hide()
                        self.alert(error)
                    } else {
                        self.noChatsView.isHidden = true
                        self.tableView.reloadData()
                        HUD.flash(.success)
                    }
                }
            }
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alert.addAction(okAction)
        alert.addAction(cancelAction)

        self.present(alert, animated: true)
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

        guard let channel = channels[safe: count - indexPath.row - 1] else {
            Log.error("Can't form row: Core Data channel wrong index")
            return cell
        }

        cell.usernameLabel.text = channel.name
        cell.letterLabel.text = channel.letter
        cell.avatarView.gradientLayer.colors = [channel.colorPair.first, channel.colorPair.second]
        cell.avatarView.gradientLayer.gradient = GradientPoint.bottomLeftTopRight.draw()

        cell.lastMessageLabel.text = channel.lastMessagesBody
        cell.lastMessageDateLabel.text = channel.lastMessagesDate?.shortString() ?? ""

        return cell
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

            guard let channel = CoreDataHelper.shared.loadChannel(withName: username),
                let count = channel.message?.count else {
                    Log.error("Channel do not exist in Core Data")
                    return
            }

            // FIXME
            VirgilHelper.shared.setChannelCard(channel.cards.first!)

            self.currentChannelMessegesCount = count

            self.performSegue(withIdentifier: "goToChat", sender: self)
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
