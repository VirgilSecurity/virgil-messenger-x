//
//  IncommingCall.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 20.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import UIKit

class IncomingCallViewController: UIViewController {

    // MARK: - UI
    @IBOutlet weak var calleeLabel: UILabel!

    // MARK: - UI handlers
    override func viewDidLoad() {
        super.viewDidLoad()

        self.calleeLabel.text = CallManager.shared.callIdentifier
    }

    @IBAction func acceptCall(_ sender: Any?) {
        CallManager.shared.acceptCall()
        Notifications.post(Notifications.EmptyNotification.acceptCall)
    }

    @IBAction func rejectCall(_ sender: Any?) {
        self.dismiss(animated: true) {
            CallManager.shared.rejectCall()
            Notifications.post(Notifications.EmptyNotification.rejectCall)
        }
    }
}
