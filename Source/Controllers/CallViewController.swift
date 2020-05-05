//
//  CallViewController.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 20.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import UIKit

class CallViewController: ViewController {

    // MARK: UI
    @IBOutlet weak var calleeLabel: UILabel!
    @IBOutlet weak var callStatusLabel: UILabel!
    @IBOutlet weak var connectionStatusLabel: UILabel!
    @IBOutlet weak var avatarLetterLabel: UILabel!
    @IBOutlet weak var avatarView: GradientView!

    // MARK: Queues
    let callStatusQueue = DispatchQueue.init(label: "CallTimeUpdateQueue")

    // MARK: State
    private var calls: [Call] = []
    private var callDurationTimer: Timer?

    // MARK: UI handlers
    override func viewDidLoad() {
        super.viewDidLoad()

        self.callDurationTimer = self.callDurationTimer ?? Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.callStatusQueue.async {
                self.updateCallView()
            }
        }

        self.updateCallView()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        self.calls.forEach { (call) in
            call.delegate = nil
        }

        self.calls.removeAll()
        self.callDurationTimer?.invalidate()
    }

    @IBAction func endCall(_ sender: Any?) {
        if let call = self.calls.first {
            CallManager.shared.endCall(call)
        }
    }

    public func addCall(call: Call) {
        call.delegate = self
        self.calls.append(call)
        self.updateCallView()
    }

    public func removeCall(call: Call) {
        call.delegate = nil
        self.calls.removeAll { $0.uuid == call.uuid }

        if !self.calls.isEmpty {
            self.updateCallView()
        }
        else {
            self.close()
        }
    }
}

// MARK: - UI helpers
extension CallViewController {
    private static var dateFormatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }

    private static func formatCallDurationThat(connectedAt: Date) -> String {
        let callDuration = -connectedAt.timeIntervalSinceNow
        let callDurationString = Self.dateFormatter.string(from: callDuration)!
        return callDurationString
    }

    private func updateCallView() {
        DispatchQueue.main.async {
            guard
                self.isViewLoaded,
                let call = self.calls.first
            else {
                Log.debug("No call to display")
                return
            }

            guard let channel = Storage.shared.getChannel(withName: call.otherName) else{
                Log.error(Storage.Error.channelNotFound, message: "Call View is unable to render")
                return
            }

            self.avatarLetterLabel.text = channel.letter
            self.avatarView.draw(with: channel.colors)

            self.calleeLabel.text = call.otherName
            self.connectionStatusLabel.text = call.connectionStatus.rawValue

            if let connectedAt = call.connectedAt {
                self.callStatusLabel.text = Self.formatCallDurationThat(connectedAt: connectedAt)
            }
            else {
                self.callStatusLabel.text = call.state.rawValue
            }
        }
    }
}

extension CallViewController: CallDelegate {
    func call(_ call: Call, didChangeState newState: CallState) {
    }

    func call(_ call: Call, didChangeConnectionStatus newConnectionStatus: CallConnectionStatus) {
        switch newConnectionStatus {
        case .closed, .disconnected, .failed:
            CallManager.shared.endCall(call)
        default:
            break
        }
    }

    func call(_ call: Call, didEnd error: Error?) {
        if let error = error {
            self.alert(error)
        }
    }

    func close() {
        DispatchQueue.main.async {
            self.dismiss(animated: true, completion: nil)
        }
    }
}
