//
//  IncommingCall.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 20.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import UIKit

class IncommingCallViewController: UIViewController {

    // MARK: - UI
    @IBOutlet weak var calleeLabel: UILabel!

    // MARK: - Functional
    private var channel: Storage.Channel!
    private var callOffer: Message.CallOffer!
    private var callManager: CallManager!

    // MARK: - Configure
    func configure(withChannel channel: Storage.Channel, callOffer: Message.CallOffer) {
        self.channel = channel
        self.callOffer = callOffer
    }

    // MARK: - UI handlers
    override func viewDidLoad() {
        super.viewDidLoad()

        self.calleeLabel.text = self.channel.name

        self.callManager = CallManager(withChannel: self.channel)
    }

    @IBAction func acceptCall(_ sender: Any?) {
        self.performSegue(withIdentifier: "goToCall", sender: nil)
    }

    @IBAction func denyCall(_ sender: Any?) {
        self.callManager.rejectCall()
        self.dismiss(animated: true, completion: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let callViewController = segue.destination as? CallViewController {
            callViewController.configureForIncommingCall(withChannel: self.channel, callOffer: self.callOffer)
            callViewController.delegate = self
        }

        super.prepare(for: segue, sender: sender)
    }
}

extension IncommingCallViewController: CallViewControllerDelegate {
    func callViewControllerWillBeClosed(_ sender: CallViewController) {
        sender.delegate = nil
        DispatchQueue.main.async {
            self.dismiss(animated: false, completion: nil)
        }
    }
}
