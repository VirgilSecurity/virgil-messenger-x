//
//  ChatListViewController.swift
//  Morse
//
//  Created by Oleksandr Deundiak on 10/18/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit
import PKHUD

class ChatListViewController: ViewController {
    @IBOutlet weak var noChatsView: UIView!
    @IBOutlet weak var tableView: UITableView!

    private let indicator = UIActivityIndicatorView()
    private let indicatorLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))

    static let name = "ChatList"

    private var channels: [Channel] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupTitleView()
        self.setupTableView()
        self.setupObservers()

        Configurator.configure()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.reloadTableView()
    }

    private func setupObservers() {
        let initialized: Notifications.Block = { [weak self] _ in
            DispatchQueue.main.async {
                self?.indicatorLabel.text = Configurator.state
            }
        }

        let updated: Notifications.Block = { [weak self] _ in
            DispatchQueue.main.async {
                self?.reloadTableView()
                self?.navigationItem.titleView = nil
                self?.title = "Chats"
                self?.indicator.stopAnimating()
            }
        }

        let reloadTableView: Notifications.Block = { [weak self] _ in
            self?.reloadTableView()
        }

        let initFailed: Notifications.Block = { [weak self] notification in
            guard let error: Error = Notifications.parse(notification, for: .error) else {
                Log.error("Invalid notification")
                return
            }

            DispatchQueue.main.async {
                self?.alert(error) { _ in
                    UserAuthorizer().logOut { error in
                        if let error = error {
                            self?.alert(error)
                        } else {
                            self?.goToLogin()
                        }
                    }
                }
            }
        }

        Notifications.observe(for: .errored, block: initFailed)
        Notifications.observe(for: .initializingSucceed, block: initialized)
        Notifications.observe(for: .updatingSucceed, block: updated)
        Notifications.observe(for: [.chatListUpdated], block: reloadTableView)
    }

    private func setupTableView() {
        let chatListCellNib = UINib(nibName: ChatListCell.name, bundle: Bundle.main)
        self.tableView.register(chatListCellNib, forCellReuseIdentifier: ChatListCell.name)
        self.tableView.rowHeight = 94
        self.tableView.tableFooterView = UIView(frame: .zero)
        self.tableView.dataSource = self
    }

    private func setupTitleView() {
        self.indicator.hidesWhenStopped = false
        self.indicator.startAnimating()

        self.indicatorLabel.textColor = .white
        self.indicatorLabel.text = Configurator.state
        let titleView = UIStackView(arrangedSubviews: [self.indicator, self.indicatorLabel])
        titleView.spacing = 5

        self.navigationItem.titleView = titleView
    }

    @objc private func reloadTableView() {
        self.channels = CoreData.shared.getChannels()

        self.channels.sort { first, second in
            let firstDate = first.lastMessagesDate ?? first.createdAt

            let secondDate = second.lastMessagesDate ?? second.createdAt

            return firstDate > secondDate
        }

        DispatchQueue.main.async {
            self.noChatsView.isHidden = !self.channels.isEmpty

            self.tableView.reloadData()
        }
    }

    @IBAction func didTapAdd(_ sender: Any) {
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

            ChatsManager.startSingle(with: username, startProgressBar: hudShow) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        HUD.hide()
                        self.alert(error)
                    } else {
                        HUD.flash(.success)
                        self.reloadTableView()
                    }
                }
            }
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alert.addAction(okAction)
        alert.addAction(cancelAction)

        self.present(alert, animated: true)
    }

    private func goToLogin() {
        DispatchQueue.main.async {
            self.switchNavigationStack(to: AuthenticationViewController.name)
        }
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

        CoreData.shared.setCurrent(channel: selectedChannel)

        self.performSegue(withIdentifier: "goToChat", sender: self)
    }


    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let chatController = segue.destination as? ChatViewController,
            let channel = CoreData.shared.currentChannel {
                chatController.channel = channel
        }

        super.prepare(for: segue, sender: sender)
    }
}
