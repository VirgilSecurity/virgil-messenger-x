//
//  ChatListViewController.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/18/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit
import PKHUD

class ChatListViewController: CallableController {
    @IBOutlet weak var noChatsView: UIView!
    @IBOutlet weak var tableView: UITableView!

    private let indicator = UIActivityIndicatorView()
    private let indicatorLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))

    static let name = "ChatList"

    var channels: [Storage.Channel] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupIndicator()
        self.updateTitleView()
        self.setupTableView()
        self.setupObservers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.reloadTableView()
    }

    private func setupObservers() {
        let connectionStateChanged: Notifications.Block = { [weak self] _ in
            guard let strongSelf = self else { return }

            DispatchQueue.main.async {
                strongSelf.updateTitleView()
            }
        }

        let reloadTableView: Notifications.Block = { [weak self] _ in
            self?.reloadTableView()
        }

        let errored: Notifications.Block = { [weak self] notification in
            do {
                let error: Error = try Notifications.parse(notification, for: .error)

                DispatchQueue.main.async {
                    self?.alert(error) { _ in
                        UserAuthorizer().logOut { error in
                            if let error = error {
                                self?.alert(error)
                            }
                            else {
                                self?.goToLogin()
                            }
                        }
                    }
                }
            }
            catch {
                Log.error(error, message: "Parsing Error notification failed")
            }
        }

        Notifications.observe(for: .errored, block: errored)
        Notifications.observe(for: .connectionStateChanged, block: connectionStateChanged)
        Notifications.observe(for: [.chatListUpdated], block: reloadTableView)
    }
}

// MARK: - UI
extension ChatListViewController {
    private func setupTableView() {
        let chatListCellNib = UINib(nibName: ChatListCell.name, bundle: Bundle.main)
        self.tableView.register(chatListCellNib, forCellReuseIdentifier: ChatListCell.name)
        self.tableView.rowHeight = 80
        self.tableView.tableFooterView = UIView(frame: .zero)
        self.tableView.dataSource = self
    }

    private func setupIndicator() {
        self.indicator.hidesWhenStopped = false
        self.indicatorLabel.textColor = .white
        self.indicatorLabel.text = "Connecting..."
    }

    private func updateTitleView() {
        switch Ejabberd.shared.state {
        case .connected:
            self.reloadTableView()
            self.navigationItem.titleView = nil
            self.title = "Chats"
            self.indicator.stopAnimating()

        case .connecting, .disconnected:
            guard !self.indicator.isAnimating else {
                return
            }

            self.indicator.startAnimating()

            let titleView = UIStackView(arrangedSubviews: [self.indicator, self.indicatorLabel])
            titleView.spacing = 5

            self.navigationItem.titleView = titleView
        }
    }

    @objc private func reloadTableView() {
        self.channels = Storage.shared.getChannels()

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
}

// MARK: - Actions
extension ChatListViewController {
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

            ChatsManager.startDrSession(with: username, startProgressBar: hudShow) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        HUD.hide()
                        self.alert(error)
                    }
                    else {
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
}

// MARK: - Navigation
extension ChatListViewController {
    func moveToChannel(_ channel: Storage.Channel) {
        Storage.shared.setCurrent(channel: channel)
        self.performSegue(withIdentifier: "goToChat", sender: self)
    }

    private func goToLogin() {
        DispatchQueue.main.async {
            self.switchNavigationStack(to: .authentication)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let chatController = segue.destination as? ChatViewController,
            let channel = Storage.shared.currentChannel {
                chatController.channel = channel
        }

        super.prepare(for: segue, sender: sender)
    }
}

// MARK: - Table View
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
        cell.backgroundColor = .appThemeForegroundColor
    }
}

extension ChatListViewController: CellTapDelegate {
    func didTapOn(_ cell: UITableViewCell) {
        guard let selectedChannel = self.channels[safe: cell.tag] else {
            Log.error(UserFriendlyError.unknownError,
                      message: "Tried to tap on Channel, which is out of range")
            return
        }

        self.moveToChannel(selectedChannel)
    }
}
