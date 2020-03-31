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

    weak var incomingCallViewController: UIViewController?
    weak var callViewController: UIViewController?

    private let indicator = UIActivityIndicatorView()
    private let indicatorLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))

    static let name = "ChatList"

    var channels: [Storage.Channel] = []

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
            do {
                let error: Error = try Notifications.parse(notification, for: .error)

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
            } catch {
                Log.error(error, message: "Parsing Error notification failed")
            }
        }

        let callOfferReceived: Notifications.Block = { [weak self] notification in
            let callOffer: NetworkMessage.CallOffer
            do {
                callOffer = try Notifications.parse(notification, for: .message)
            } catch {
                Log.error(error, message: "Invalid call offer notification")
                return
            }

            guard let callChannel = self?.channels.first(where: { $0.name == callOffer.caller }) else {
                // FIXME:
                Log.error(UserFriendlyError.userNotFound, message: "Caller is unknown")
                return
            }

            CallManager.shared.startIncommingCall(callOffer: callOffer, in: callChannel)
            Notifications.post(Notifications.EmptyNotification.startIncommingCall)
        }

        let iceCandidateReceived: Notifications.Block = { [weak self] notification in
            if self == nil {
                return
            }

            let iceCandidate: NetworkMessage.IceCandidate
            do {
                iceCandidate = try Notifications.parse(notification, for: .message)
            } catch {
                Log.error(error, message: "Invalid ice cadidate notification")
                return
            }

            CallManager.shared.addIceCandidate(iceCandidate)
        }

        let callIsAccepted: Notifications.Block = { [weak self] notification in
            if self == nil {
                return
            }

            let callAceptedAnswer: NetworkMessage.CallAcceptedAnswer
            do {
                callAceptedAnswer = try Notifications.parse(notification, for: .message)
            } catch {
                Log.error(error, message: "Invalid call accepted answer notification")
                return
            }

            CallManager.shared.processCallAcceptedAnswer(callAceptedAnswer)
            Notifications.post(Notifications.EmptyNotification.acceptCall)
        }

        let callIsRejected: Notifications.Block = { [weak self] notification in
            if self == nil {
                return
            }

            let callRejectedAnswer: NetworkMessage.CallRejectedAnswer
            do {
                callRejectedAnswer = try Notifications.parse(notification, for: .message)
            } catch {
                Log.error(error, message: "Invalid call rejected answer notification")
                return
            }

            CallManager.shared.processCallRejectedAnswer(callRejectedAnswer)
            Notifications.post(Notifications.EmptyNotification.rejectCall)
        }

        let startIncommingCall: Notifications.Block = { [weak self] _ in
            guard let sSelf = self else {
                return
            }

            DispatchQueue.main.async {
                let storyboard = UIStoryboard(name: "IncomingCall", bundle: nil)
                let incomingCallViewController = storyboard.instantiateViewController(withIdentifier: "IncomingCall")

                incomingCallViewController.modalPresentationStyle = .fullScreen
                incomingCallViewController.modalTransitionStyle = .crossDissolve

                sSelf.incomingCallViewController = incomingCallViewController

                sSelf.present(incomingCallViewController, animated: true, completion: nil)
            }
        }

        let startOugoingCall: Notifications.Block = { [weak self] _ in
            guard let sSelf = self else {
                return
            }

            DispatchQueue.main.async {
                let storyboard = UIStoryboard(name: "Call", bundle: nil)
                let callViewController = storyboard.instantiateViewController(withIdentifier: "Call")

                callViewController.modalPresentationStyle = .fullScreen
                callViewController.modalTransitionStyle = .crossDissolve

                sSelf.callViewController = callViewController

                sSelf.present(callViewController, animated: true, completion: nil)
            }
        }

        let acceptCall: Notifications.Block = { [weak self] _ in
            guard let sSelf = self else {
                return
            }

            DispatchQueue.main.async {
                let storyboard = UIStoryboard(name: "Call", bundle: nil)
                let callViewController = storyboard.instantiateViewController(withIdentifier: "Call")

                callViewController.modalPresentationStyle = .fullScreen
                callViewController.modalTransitionStyle = .crossDissolve

                sSelf.callViewController = callViewController

                sSelf.incomingCallViewController?.dismiss(animated: false, completion: nil)
                sSelf.present(callViewController, animated: true, completion: nil)
            }
        }

        let rejectCall: Notifications.Block = { _ in
            // TODO: Show "Recall" view controller instead
        }

        Notifications.observe(for: .errored, block: initFailed)
        Notifications.observe(for: .initializingSucceed, block: initialized)
        Notifications.observe(for: .updatingSucceed, block: updated)
        Notifications.observe(for: [.chatListUpdated], block: reloadTableView)
        Notifications.observe(for: .callOfferReceived, block: callOfferReceived)
        Notifications.observe(for: .iceCandidateReceived, block: iceCandidateReceived)
        Notifications.observe(for: .callIsAccepted, block: callIsAccepted)
        Notifications.observe(for: .callIsRejected, block: callIsRejected)
        Notifications.observe(for: .startIncommingCall, block: startIncommingCall)
        Notifications.observe(for: .startOugoingCall, block: startOugoingCall)
        Notifications.observe(for: .acceptCall, block: acceptCall)
        Notifications.observe(for: .rejectCall, block: rejectCall)
    }

    private func setupTableView() {
        let chatListCellNib = UINib(nibName: ChatListCell.name, bundle: Bundle.main)
        self.tableView.register(chatListCellNib, forCellReuseIdentifier: ChatListCell.name)
        self.tableView.rowHeight = 80
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
        cell.backgroundColor = UIColor(rgb: 0x2B303B)
    }
}

extension ChatListViewController: CellTapDelegate {
    func didTapOn(_ cell: UITableViewCell) {
        guard let selectedChannel = self.channels[safe: cell.tag] else {
            Log.error(UserFriendlyError.unknownError,
                      message: "Tried to tap on Storage.Channel, which is out of range")
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
