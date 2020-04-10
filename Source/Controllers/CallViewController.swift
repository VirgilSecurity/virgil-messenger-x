//
//  Call.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 20.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import UIKit

class CallViewController: UIViewController {

    // MARK: UI
    @IBOutlet weak var calleeLabel: UILabel!
    @IBOutlet weak var callStatusLabel: UILabel!
    @IBOutlet weak var connectionStatusLabel: UILabel!

    // MARK: State
    weak var call: Call?

    // MARK: UI handlers

    override func viewWillAppear(_ animated: Bool) {
        guard let call = self.call else {
            return
        }

        self.calleeLabel.text = call.opponent
        self.callStatusLabel.text = call.state.rawValue
        self.connectionStatusLabel.text = call.connectionStatus.rawValue

        call.delegate = self
    }

    override func viewWillDisappear(_ animated: Bool) {
        self.call?.delegate = nil
    }

    @IBAction func endCall(_ sender: Any?) {
        if let call = self.call {
            CallManager.shared.endCall(call)
        } else {
            self.close()
        }
    }
}

extension CallViewController: CallDelegate {
    func call(_ call: Call, didChangeState newState: CallState) {
        DispatchQueue.main.async {
            self.callStatusLabel.text = newState.rawValue
        }
    }

    func call(_ call: Call, didChangeConnectionStatus newConnectionStatus: CallConnectionStatus) {
        DispatchQueue.main.async {
            self.connectionStatusLabel.text = newConnectionStatus.rawValue
        }
    }

    func call(_ call: Call, didEnd error: Error?) {
        if let error = error {
            self.alert(error) { _ in
                self.close()
            }
        } else {
            self.close()
        }
    }

    func close() {
        DispatchQueue.main.async {
            self.dismiss(animated: true, completion: nil)
        }
    }
}
