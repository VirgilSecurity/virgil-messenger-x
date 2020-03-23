//
//  Call.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 20.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import UIKit

protocol CallViewControllerDelegate: class {
    func callViewControllerWillBeClosed(_ sender: CallViewController)
}

class CallViewController: UIViewController {

    // MARK: - UI
    @IBOutlet weak var calleeLabel: UILabel!
    @IBOutlet weak var callStatusLabel: UILabel!
    @IBOutlet weak var connectionStatusLabel: UILabel!

    // MARK: - Functional
    private var channel: Storage.Channel!
    private var callManager: CallManager!
    private var callOffer: Message.CallOffer?

    // MARK: - Delegate
    weak var delegate: CallViewControllerDelegate?

    // MARK: - Configuration
    func configureForOutgoingCall(withChannel channel: Storage.Channel) {
        self.channel = channel
        self.callOffer = nil
    }

    func configureForIncommingCall(withChannel channel: Storage.Channel, callOffer: Message.CallOffer) {
        self.channel = channel
        self.callOffer = callOffer
    }

    // MARK: - UI handlers
    override func viewDidLoad() {
        super.viewDidLoad()

        self.calleeLabel.text = self.channel.name

        self.setupNotificationObservers()

        self.callManager = CallManager(withChannel: self.channel)
        self.callManager.delegate = self

        if let callOffer = self.callOffer {
            self.callManager.acceptCall(offer: callOffer)
        } else {
            self.callManager.startCall()
        }
    }

    @IBAction func endCall(_ sender: Any?) {
        self.callManager.endCall()
        self.delegate?.callViewControllerWillBeClosed(self)
        self.dismiss(animated: true, completion: nil)
    }

    // MARK: - Observers
    private func setupNotificationObservers() {
        let processCallAcceptedAnswer: Notifications.Block = { [weak self] notification in
            let callAceptedAnswer: Message.CallAcceptedAnswer
            do {
                callAceptedAnswer = try Notifications.parse(notification, for: .message)
            } catch {
                Log.error(error, message: "Invalid call accepted answer notification")
                return
            }

            self?.callManager.processAcceptedAnswer(callAceptedAnswer)
        }

        Notifications.observe(for: .callIsAccepted, block: processCallAcceptedAnswer)

        let processCallRejectedAnswer: Notifications.Block = { [weak self] notification in
            let callRejectedAnswer: Message.CallRejectedAnswer
            do {
                callRejectedAnswer = try Notifications.parse(notification, for: .message)
            } catch {
                Log.error(error, message: "Invalid call rejected answer notification")
                return
            }

            self?.callManager.processRejectedAnswer(callRejectedAnswer)
        }

        Notifications.observe(for: .callIsRejected, block: processCallRejectedAnswer)

        let processIceCandidate: Notifications.Block = { [weak self] notification in
            let iceCandidate: Message.IceCandidate
            do {
                iceCandidate = try Notifications.parse(notification, for: .message)
            } catch {
                Log.error(error, message: "Invalid ice cadidate notification")
                return
            }

            self?.callManager.addIceCandidate(iceCandidate)
        }

        Notifications.observe(for: .iceCandidateReceived, block: processIceCandidate)
    }
}

extension CallViewController: CallManagerDelegate {
    func callManagerWillStartCall(_ sender: CallManager) {
        DispatchQueue.main.async {
            self.callStatusLabel.text = CallStatusString.startCalling
        }
    }

    func callManagerDidStartCall(_ sender: CallManager) {
        DispatchQueue.main.async {
            self.callStatusLabel.text = CallStatusString.waitingForAnswer
            self.connectionStatusLabel.text = ConnectionStatusString.connecting
        }
    }

    func callManagerDidAcceptCall(_ sender: CallManager) {
        DispatchQueue.main.async {
            self.callStatusLabel.text = CallStatusString.negotiateConnection
        }
    }

    func callManagerDidRejectCall(_ sender: CallManager) {
        DispatchQueue.main.async {
            self.callStatusLabel.text = CallStatusString.rejected
            self.connectionStatusLabel.text = ConnectionStatusString.undefined
            self.delegate?.callViewControllerWillBeClosed(self)
            self.dismiss(animated: true, completion: nil)
        }
    }

    func callManagerWillEndCall(_ sender: CallManager) {
    }

    func callManagerDidEndCall(_ sender: CallManager) {
        DispatchQueue.main.async {
            self.callStatusLabel.text = CallStatusString.finished
            self.connectionStatusLabel.text = ConnectionStatusString.disconnected
            self.delegate?.callViewControllerWillBeClosed(self)
            self.dismiss(animated: true, completion: nil)
        }
    }

    func callManagerDidConnect(_ sender: CallManager) {
        DispatchQueue.main.async {
            self.callStatusLabel.text = CallStatusString.connected
            self.connectionStatusLabel.text = ConnectionStatusString.connected
        }
    }

    func callManagerLoseConnection(_ sender: CallManager) {
        DispatchQueue.main.async {
            self.connectionStatusLabel.text = ConnectionStatusString.loseConnection
        }
    }

    func callManagerStartReconnecting(_ sender: CallManager) {
        DispatchQueue.main.async {
            self.callStatusLabel.text = CallStatusString.cannotConnect
            self.connectionStatusLabel.text = ConnectionStatusString.reconnecting
        }
    }

    func callManagerIsConnecting(_ sender: CallManager) {
        DispatchQueue.main.async {
            self.connectionStatusLabel.text = ConnectionStatusString.connecting
        }
    }

    func callManagerDidFail(_ sender: CallManager, error: Error?) {
        if let error = error {
            Log.error(error, message: "Call did fail")
        }

        DispatchQueue.main.async {
            self.callStatusLabel.text = CallStatusString.cannotConnect
            self.connectionStatusLabel.text = ConnectionStatusString.failed
        }

        sender.endCall()
    }
}
