//
//  VoiceCall.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/3/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import UIKit

class VoiceCallViewController: ViewController {
    @IBOutlet weak var callDirectionLabel: UILabel!
    @IBOutlet weak var callToFromLabel: UILabel!
    @IBOutlet weak var callToFromNameLabel: UILabel!
    @IBOutlet weak var callStatus: UILabel!
    @IBOutlet weak var callButton: UIButton!
    @IBOutlet weak var answerButton: UIButton!

    enum CallState {
        case none
        case initial
        case callerWaitingForAnswer
        case responderWaitingForAnswer
        case waitingIceNegotiating
        case connected
        case abort(Error)
    }

    private var callState: CallState = .none {
        willSet {
            DispatchQueue.main.async {
                switch (self.callState) {
                case .none:
                    break;
                    
                case .initial:
                    self.callDirectionLabel.text = "-"
                    self.callToFromLabel.text = "To"
                    self.callStatus.text = "Initial"
                    self.callToFromNameLabel.text = self.callChannel.dataSource.channel.name
                    self.callButton.isEnabled = true
                    self.answerButton.isEnabled = false

                case .callerWaitingForAnswer:
                    self.callStatus.text = "Waiting for answer..."
                    self.callButton.isEnabled = false
                    self.answerButton.isEnabled = false
                    
                case .responderWaitingForAnswer:
                    self.callDirectionLabel.text = "Incomming"
                    self.callToFromLabel.text = "From"
                    self.callStatus.text = "Answer please"
                    self.callToFromNameLabel.text = self.callChannel.dataSource.channel.name
                    self.callButton.isEnabled = false
                    self.answerButton.isEnabled = true

                case .waitingIceNegotiating:
                    self.callStatus.text = "Waiting ice negotiating..."
                    self.callButton.isEnabled = false
                    self.answerButton.isEnabled = false
                    
                case .connected:
                    self.callStatus.text = "Connected"
                    
                case .abort(let error):
                    self.callStatus.text = error.localizedDescription
                }
            }
        }
    }
    
    private var lastCallOfferSessionDescription: CallSessionDescription?
    
    public var callChannel: CallChannel! {
        didSet {
            self.callChannel.delegate = self
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.callState = .initial
        self.setupObservers()
    }
        
    private func setupObservers() {
        let processCallOffer: Notifications.Block = { [weak self] notification in
            guard let callOffer: MessageContent.CallOffer = Notifications.parse(notification, for: .message) else {
                Log.error("Invalid call offer notification")
                return
            }

            self?.callState = .responderWaitingForAnswer
            self?.lastCallOfferSessionDescription = callOffer.sdp
        }
        Notifications.observe(for: .callOfferReceived, block: processCallOffer)

        let processCallAnswer: Notifications.Block = { [weak self] notification in
            guard let callAnswer: MessageContent.CallAnswer = Notifications.parse(notification, for: .message) else {
                Log.error("Invalid call answer notification")
                return
            }

            self?.callChannel.acceptAnswer(callAnswer.sdp) { error in
                guard let error = error else {
                    self?.callState = .waitingIceNegotiating
                    return
                }
                
                Log.error("\(error)")
                self?.callState = .abort(error)
                self?.callChannel.endCall()
            }
        }
        Notifications.observe(for: .callAnswerReceived, block: processCallAnswer)

        let processIceCandidate: Notifications.Block = { [weak self] notification in
            guard let iceCandidate: MessageContent.IceCandidate = Notifications.parse(notification, for: .message) else {
                Log.error("Invalid ice cadidate notification")
                return
            }

            self?.callChannel.addIceCandidate(iceCandidate.iceCandidate)
        }
        Notifications.observe(for: .iceCandidateReceived, block: processIceCandidate)
    }

    @IBAction func sendOfferTapped(_ sender: Any) {
        Log.debug("Send Offer tapped")

        self.callChannel.sendOffer { error in
            guard let error = error else {
                Log.debug("Voice offer was created")
                self.callState = .callerWaitingForAnswer
                return
            }
            
            Log.error("Voice offer was not created \(error)")
            self.callState = .abort(error)
            self.callChannel.endCall()
        }
    }
    
    @IBAction func sendAnswerTapped(_ sender: Any) {
        
        if let sessionDescription = self.lastCallOfferSessionDescription {
            self.callChannel.sendAnswer(offer: sessionDescription) { error in
                guard let error = error else {
                    Log.debug("Voice offer was created")
                    return
                }
                
                Log.error("Voice offer was not created \(error)")
            }
        }
    }
    
    @IBAction func endCallTapped(_ sender: Any) {
        self.callChannel.endCall()
        dismiss(animated: true, completion: nil)
    }
}

extension VoiceCallViewController: CallChannelDelegate {
    func callChannel(connected callChannel: CallChannel) {
        Log.debug("!!! Call Connected")
        self.callState = .connected
    }
}
