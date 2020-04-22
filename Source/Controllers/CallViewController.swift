//
//  CallViewController.swift
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
    var callDuration: TimeInterval = 0.0
    var callDurationTimer: Timer!

    // MARK: UI handlers
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let call = self.call else {
            return
        }

        self.calleeLabel.text = call.otherName
        self.callStatusLabel.text = call.state.rawValue
        self.connectionStatusLabel.text = call.connectionStatus.rawValue

        self.callDurationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (_) in
            self.callDuration += 1.0
            self.updateCallStatus()
        }

        call.delegate = self
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        self.call?.delegate = nil
        self.callDurationTimer.invalidate()
    }

    @IBAction func endCall(_ sender: Any?) {
        if let call = self.call {
            CallManager.shared.endCall(call)
        }
        else {
            self.close()
        }
    }}

// MARK: - UI helpers
extension CallViewController {
    private static var dateFormatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }

    private func updateCallStatus() {
        guard let call = self.call else {
            return
        }

        let callStatusString: String
        if call.connectionStatus == .connected {
            callStatusString = Self.dateFormatter.string(from: self.callDuration)!
        }
        else {
            callStatusString = call.state.rawValue
        }

        DispatchQueue.main.async {
            self.callStatusLabel.text = callStatusString
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
        }
        else {
            self.close()
        }
    }

    func close() {
        DispatchQueue.main.async {
            self.dismiss(animated: true, completion: nil)
        }
    }
}
