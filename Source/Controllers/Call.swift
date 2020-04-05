//
//  Call.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 20.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import UIKit

class CallViewController: UIViewController {

    // MARK: - UI
    @IBOutlet weak var calleeLabel: UILabel!
    @IBOutlet weak var callStatusLabel: UILabel!
    @IBOutlet weak var connectionStatusLabel: UILabel!

    // MARK: - UI handlers
    override func viewDidLoad() {
        super.viewDidLoad()

        self.calleeLabel.text = CallManager.shared.callIdentifier
        self.callStatusLabel.text = Self.stringify(callDirection: CallManager.shared.callDirection)
        self.connectionStatusLabel.text = Self.stringify(connectionStatus: CallManager.shared.connectionStatus)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        CallManager.shared.addObserver(self)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        CallManager.shared.removeObserver(self)
    }

    @IBAction func endCall(_ sender: Any?) {
        self.dismiss(animated: true) {
            CallManager.shared.endCall()
        }
    }
}

extension CallViewController: CallManagerObserver {

    static func stringify(connectionStatus: CallManager.ConnectionStatus) -> String {
        switch connectionStatus {
        case .none:
            return "..."

        case .new:
            return "new"

        case .waitingForAnswer:
            return "waitingForAnswer"

        case .rejected:
            return "rejected"

        case .acceptAnswer:
            return "acceptAnswer"

        case .negotiating:
            return "negotiating"

        case .connected:
            return "connected"

        case .disconnected:
            return "disconnected"

        case .closed:
            return "closed"

        case .failed(let error):
            // FIXME: Show user friendly error
            return error.localizedDescription
        }
    }

    static func stringify(callDirection: CallManager.CallDirection) -> String {
        switch callDirection {
        case .none:
            return ""

        case .incoming:
            return  "Incoming call"

        case .outgoing:
            return  "Outgoing call"
        }
    }


    func callManager(_ callManager: CallManager, didChange newConnectionStatus: CallManager.ConnectionStatus) {
        DispatchQueue.main.async {
            self.connectionStatusLabel.text = Self.stringify(connectionStatus: newConnectionStatus)
        }

        if (newConnectionStatus == .closed) || (newConnectionStatus == .failed(CallManagerError.connectionFailed)) {
            DispatchQueue.main.async {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
}
