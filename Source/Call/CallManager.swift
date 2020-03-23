//
//  WebRTCChannel.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 04.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import WebRTC

private let kIceServers = ["stun:stun.l.google.com:19302",
                  "stun:stun1.l.google.com:19302",
                  "stun:stun2.l.google.com:19302",
                  "stun:stun3.l.google.com:19302",
                  "stun:stun4.l.google.com:19302"]

public protocol CallManagerDelegate: class {
    func callManagerWillStartCall(_ sender: CallManager)
    func callManagerDidStartCall(_ sender: CallManager)
    func callManagerWillEndCall(_ sender: CallManager)
    func callManagerDidEndCall(_ sender: CallManager)
    func callManagerDidConnect(_ sender: CallManager)
    func callManagerLoseConnection(_ sender: CallManager)
    func callManagerStartReconnecting(_ sender: CallManager)
    func callManagerIsConnecting(_ sender: CallManager)
    func callManagerDidAcceptCall(_ sender: CallManager)
    func callManagerDidRejectCall(_ sender: CallManager)
    func callManagerDidFail(_ sender: CallManager, error: Error?)
}

public class CallManager: NSObject {

    public weak var delegate: CallManagerDelegate?

    private static let factory: RTCPeerConnectionFactory = RTCPeerConnectionFactory()

    private let rtcAudioSession =  RTCAudioSession.sharedInstance()

    private var peerConnection: RTCPeerConnection?

    private let messageSender: MessageSender

    private let channel: Storage.Channel


    required init(withChannel channel: Storage.Channel) {
        self.messageSender = MessageSender()
        self.channel = channel

        super.init()
    }

    func startCall() {
        self.delegate?.callManagerWillStartCall(self)

        let constrains = RTCMediaConstraints(mandatoryConstraints:
                [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue], optionalConstraints: nil)

        self.peerConnection?.close()
        self.peerConnection = Self.createPeerConnection()

        do {
            try self.configurePeerConnection()
        }
        catch {
            self.delegate?.callManagerDidFail(self, error: error)
            return
        }

        self.peerConnection!.offer(for: constrains) { sdp, error in
            guard let sdp = sdp else {
                assert(error != nil)
                self.delegate?.callManagerDidFail(self, error: error!)
                return
            }

            self.peerConnection!.setLocalDescription(sdp) { error in
                guard let error = error else {
                    self.sendSignalingMessage(offer: sdp) { error in
                        guard let error = error else {
                            self.delegate?.callManagerDidStartCall(self)
                            return
                        }

                        self.delegate?.callManagerDidFail(self, error: error)
                    }
                    return
                }

                self.delegate?.callManagerDidFail(self, error: error)
            }
        }
    }

    func rejectCall() {
        self.sendSignalingMessageCallRejectedAnswer() { (error) in
            if let error = error {
                Log.error(error, message: "Failed to send call rejection")
            }
        }
    }

    func acceptCall(offer offerSessionDescription: Message.CallOffer) {

        self.peerConnection?.close()
        self.peerConnection = Self.createPeerConnection()
        do {
            try self.configurePeerConnection()
        } catch {
            self.delegate?.callManagerDidFail(self, error: error)
            return
        }

        let constrains = RTCMediaConstraints(mandatoryConstraints: [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue],
                                             optionalConstraints: nil)

        let offerSdp = offerSessionDescription.rtcSessionDescription
        self.peerConnection!.setRemoteDescription(offerSdp) { error in
            if let error = error {
                self.delegate?.callManagerDidFail(self, error: error)
                return
            }

            self.peerConnection!.answer(for: constrains) { localSDP, error in
                guard let answerSdp = localSDP else {
                    self.delegate?.callManagerDidFail(self, error: error)
                    return
                }

                self.peerConnection!.setLocalDescription(answerSdp) { error in
                    guard let error = error else {
                        self.sendSignalingMessage(callAcceptedAnswer: answerSdp) { (error) in
                            guard let error = error else {
                                self.delegate?.callManagerDidAcceptCall(self)
                                return
                            }

                            self.delegate?.callManagerDidFail(self, error: error)
                        }
                        return
                    }

                    self.delegate?.callManagerDidFail(self, error: error)
                }
            }
        }
    }

    func processAcceptedAnswer(_ callAnswer: Message.CallAcceptedAnswer) {
        let sdp = callAnswer.rtcSessionDescription

        self.peerConnection?.setRemoteDescription(sdp) { (error) in
            if let error = error {
                self.delegate?.callManagerDidFail(self, error: error)
            } else {
                self.delegate?.callManagerDidAcceptCall(self)
            }
        }
    }

    func processRejectedAnswer(_ callAnswer: Message.CallRejectedAnswer) {
        self.endCall()
        self.delegate?.callManagerDidRejectCall(self)
    }

    func addIceCandidate(_ iceCandidate: Message.IceCandidate) {
        self.peerConnection?.add(iceCandidate.rtcIceCandidate)
    }

    func endCall() {
        if let peerConnection = self.peerConnection {
            self.delegate?.callManagerWillEndCall(self)

            peerConnection.close()

            self.peerConnection = nil

            self.delegate?.callManagerDidEndCall(self)
        }
    }

    private static func createPeerConnection() -> RTCPeerConnection {

        let rtcConfig = RTCConfiguration()

        let rtcIceServer = RTCIceServer(urlStrings: kIceServers)
        rtcConfig.iceServers = [rtcIceServer]
        rtcConfig.sdpSemantics = .unifiedPlan
        rtcConfig.continualGatheringPolicy = .gatherContinually

        let rtcConstraints = RTCMediaConstraints(mandatoryConstraints: nil,
                                              optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue])

        return self.factory.peerConnection(with: rtcConfig, constraints: rtcConstraints, delegate: nil)
    }

    private func configurePeerConnection() throws {
        guard let peerConnection = self.peerConnection else {
            return
        }

        // Audio
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = Self.factory.audioSource(with: audioConstrains)
        let audioTrack = Self.factory.audioTrack(with: audioSource, trackId: "audio0")
        peerConnection.add(audioTrack, streamIds: ["stream"])

        // Audio session
        self.rtcAudioSession.lockForConfiguration()
        try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
        try self.rtcAudioSession.setMode(AVAudioSession.Mode.voiceChat.rawValue)
        self.rtcAudioSession.unlockForConfiguration()

        // Delegates
        peerConnection.delegate = self
    }

    func sendSignalingMessage(offer sdp: RTCSessionDescription, completion: @escaping (_ error: Error?) -> Void) {
        // FIXME: Maybe account can be obtained in another way
        guard let accout = Storage.shared.currentAccount else {
            // TODO: Change error code if necessary
            completion(UserFriendlyError.userNotFound)
            return
        }

        let callOffer = Message.CallOffer(from: sdp, caller: accout.identity)

        self.messageSender.send(callOffer: callOffer, date: Date(), channel: self.channel, completion: completion)
    }

    func sendSignalingMessage(callAcceptedAnswer sdp: RTCSessionDescription, completion: @escaping (_ error: Error?) -> Void) {
        let callAcceptedAnswer = Message.CallAcceptedAnswer(from: sdp)

        self.messageSender.send(callAcceptedAnswer: callAcceptedAnswer, date: Date(), channel: self.channel, completion: completion)
    }

    func sendSignalingMessage(candidate rtcIceCandidate: RTCIceCandidate, completion: @escaping (_ error: Error?) -> Void) {
        let iceCandiadte = Message.IceCandidate(from: rtcIceCandidate)

        self.messageSender.send(iceCandidate: iceCandiadte, date: Date(), channel: self.channel, completion: completion)
    }

    func sendSignalingMessageCallRejectedAnswer(completion: @escaping (_ error: Error?) -> Void) {
        let callRejectedAnswer = Message.CallRejectedAnswer()

        self.messageSender.send(callRejectedAnswer: callRejectedAnswer, date: Date(), channel: self.channel, completion: completion)
    }
}
