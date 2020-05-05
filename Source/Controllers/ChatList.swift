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

    weak var callViewController: CallViewController?

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

        // TODO: Move to separate class
        let callOfferReceived: Notifications.Block = { [weak self] notification in
            if self == nil {
                return
            }

            let callOffer: NetworkMessage.CallOffer
            do {
                callOffer = try Notifications.parse(notification, for: .message)
            }
            catch {
                Log.error(error, message: "Invalid call offer notification")
                return
            }

            let callDelay = -callOffer.date.timeIntervalSinceNow

            if callDelay < 10.0 {
                CallManager.shared.startIncomingCall(from: callOffer) {}
            } else {
                Log.debug("Detected stale call offer with id: \(callOffer.callUUID)")
            }
        }

        let iceCandidateReceived: Notifications.Block = { [weak self] notification in
            if self == nil {
                return
            }

            let iceCandidate: NetworkMessage.IceCandidate
            do {
                iceCandidate = try Notifications.parse(notification, for: .message)
            }
            catch {
                Log.error(error, message: "Invalid ice cadidate notification")
                return
            }

            CallManager.shared.processIceCandidate(iceCandidate)
        }

        let callAnswerReceived: Notifications.Block = { [weak self] notification in
            if self == nil {
                return
            }

            let callAnswer: NetworkMessage.CallAnswer
            do {
                callAnswer = try Notifications.parse(notification, for: .message)
            }
            catch {
                Log.error(error, message: "Invalid call accepted answer notification")
                return
            }

            CallManager.shared.processCallAnswer(callAnswer)
        }

        let callUpdateReceived: Notifications.Block = { [weak self] notification in
            if self == nil {
                return
            }

            let callUpdate: NetworkMessage.CallUpdate
            do {
                callUpdate = try Notifications.parse(notification, for: .message)
            }
            catch {
                Log.error(error, message: "Invalid call update notification")
                return
            }

            CallManager.shared.processCallUpdate(callUpdate)
        }

        CallManager.shared.delegate = self

        Notifications.observe(for: .errored, block: errored)
        Notifications.observe(for: .connectionStateChanged, block: connectionStateChanged)
        Notifications.observe(for: [.chatListUpdated], block: reloadTableView)
        Notifications.observe(for: .callOfferReceived, block: callOfferReceived)
        Notifications.observe(for: .iceCandidateReceived, block: iceCandidateReceived)
        Notifications.observe(for: .callAnswerReceived, block: callAnswerReceived)
        Notifications.observe(for: .callUpdateReceived, block: callUpdateReceived)
    }

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

    private func goToLogin() {
        DispatchQueue.main.async {
            self.switchNavigationStack(to: .authentication)
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

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let chatController = segue.destination as? ChatViewController,
            let channel = Storage.shared.currentChannel {
                chatController.channel = channel
        }

        super.prepare(for: segue, sender: sender)
    }
}

extension ChatListViewController {
    func moveToChannel(_ channel: Storage.Channel) {
        Storage.shared.setCurrent(channel: channel)
        self.performSegue(withIdentifier: "goToChat", sender: self)
    }
}

extension ChatListViewController: CallManagerDelegate {
    func callManager(_ callManager: CallManager, didAddCall call: Call) {
        DispatchQueue.main.async {
            // Use existing.
            if let callViewController = self.callViewController {
                callViewController.addCall(call: call)

                if callViewController.viewIfLoaded?.window == nil {
                    self.present(callViewController, animated: true, completion: nil)
                }
                return
            }

            // Create new.
            let storyboard = UIStoryboard(name: "Call", bundle: nil)
            let viewController = storyboard.instantiateViewController(withIdentifier: "Call")

            viewController.modalPresentationStyle = .fullScreen
            viewController.modalTransitionStyle = .crossDissolve

            guard let callViewController = viewController as? CallViewController else {
                fatalError("ViewController with identifier 'Call' is not of type CallViewController")
            }

            callViewController.addCall(call: call)

            self.callViewController = callViewController

            self.present(callViewController, animated: true, completion: nil)
        }
    }

    func callManager(_ callManager: CallManager, didRemoveCall call: Call) {
        self.callViewController?.removeCall(call: call)
    }

    func callManager(_ callManager: CallManager, didFail error: Error) {
        DispatchQueue.main.async {
            self.alert(error)
        }
    }

    func callManager(_ callManager: CallManager, didFailCall call: Call, error: Error) {
    }
}
