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

    private let configurator = Configurator()

    private var channels: [Channel] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        self.configurate()

        self.setupTableView()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.reloadTableView),
                                               name: Notification.Name(rawValue: TwilioHelper.Notifications.ChannelAdded.rawValue),
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.reloadTableView),
                                               name: Notification.Name(rawValue: TwilioHelper.Notifications.MessageAdded.rawValue),
                                               object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if self.configurator.isConfigured {
            TwilioHelper.shared.deselectChannel()
        }

        self.reloadTableView()
    }

    private func setupTableView() {
        let chatListCellNib = UINib(nibName: ChatListCell.name, bundle: Bundle.main)
        self.tableView.register(chatListCellNib, forCellReuseIdentifier: ChatListCell.name)
        self.tableView.rowHeight = 94
        self.tableView.tableFooterView = UIView(frame: .zero)
        self.tableView.dataSource = self
    }

    private func configurate() {
        self.navigationController?.view.isUserInteractionEnabled = false
        self.tabBarController?.tabBar.isUserInteractionEnabled = false

        let indicator = UIActivityIndicatorView()
        indicator.hidesWhenStopped = false
        indicator.startAnimating()

        let titleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))
        titleLabel.textColor = .white
        titleLabel.text = "Updating"
        let titleView = UIStackView(arrangedSubviews: [indicator, titleLabel])
        titleView.spacing = 5

        self.navigationItem.titleView = titleView

        self.configurator.configure { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.alert(error) { _ in
                        self.goToLogin()
                    }
                }

                self.reloadTableView()
                self.navigationItem.titleView = nil
                self.title = "Chats"
                self.navigationController?.view.isUserInteractionEnabled = true
                self.tabBarController?.tabBar.isUserInteractionEnabled = true
                indicator.stopAnimating()
            }
        }
    }

    @objc private func reloadTableView() {
        DispatchQueue.main.async {
            self.channels = CoreDataHelper.shared.getChannels()

            self.channels.sort { first, second in
                guard let firstDate = first.lastMessagesDate else {
                    return false
                }

                guard let secondDate = second.lastMessagesDate else {
                    return true
                }

                return firstDate > secondDate
            }

            self.noChatsView.isHidden = !self.channels.isEmpty

            self.tableView.reloadData()
        }
    }

    @IBAction func didTapAdd(_ sender: Any) {
        self.performSegue(withIdentifier: "goToNewMessage", sender: self)
    }

    private func goToLogin() {
        self.switchNavigationStack(to: AuthenticationViewController.name)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension ChatListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChatListCell.name) as! ChatListCell

        cell.tag = indexPath.row
        cell.delegate = self

        cell.configure(with: self.channels)

        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.channels.count
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = UIColor(rgb: 0x2B303B)
    }
}

extension ChatListViewController: CellTapDelegate {
    func didTapOn(_ cell: UITableViewCell) {
        guard let selectedChannel = self.channels[safe: cell.tag] else {
            Log.error("Channel is out of range")
            return
        }

        CoreDataHelper.shared.setCurrent(channel: selectedChannel)

        self.performSegue(withIdentifier: "goToChat", sender: self)
    }


    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let chatController = segue.destination as? ChatViewController,
            let channel = CoreDataHelper.shared.currentChannel {
                chatController.channel = channel
        }

        super.prepare(for: segue, sender: sender)
    }
}
