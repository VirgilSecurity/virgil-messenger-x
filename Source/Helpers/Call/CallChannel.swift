//
//  WebRTCChannel.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 04.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import WebRTC


fileprivate let kIceServers = ["stun:stun.l.google.com:19302",
                  "stun:stun1.l.google.com:19302",
                  "stun:stun2.l.google.com:19302",
                  "stun:stun3.l.google.com:19302",
                  "stun:stun4.l.google.com:19302"]


public protocol CallChannelDelegate: class {
    func callChannel(connected callChannel: CallChannel)
}


public class CallChannel: NSObject {

    public weak var delegate: CallChannelDelegate?

    private static let factory: RTCPeerConnectionFactory = RTCPeerConnectionFactory()

    private let rtcAudioSession =  RTCAudioSession.sharedInstance()
    
    private var peerConnection: RTCPeerConnection?

    let dataSource: DataSource
    
    required init(dataSource: DataSource) {
        self.dataSource = dataSource
        
        super.init()
    }
    
    func sendOffer(completion: @escaping (_ error: Error?) -> Void) {
        let constrains = RTCMediaConstraints(mandatoryConstraints:[kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue],
                                             optionalConstraints: nil)
        
        self.peerConnection?.close()
        self.peerConnection = Self.createPeerConnection()
        do {
            try self.configurePeerConnection()
        } catch {
            completion(error)
            return
        }

        self.peerConnection!.offer(for: constrains) { sdp, error in
            guard let sdp = sdp else {
                completion(error)
                return
            }
            
            self.peerConnection!.setLocalDescription(sdp) { error in
                if error == nil {
                    self.sendSignalingMessage(offer: sdp, completion: completion)
                }
                
                completion(error)
            }
        }
    }

    func sendAnswer(offer offerSessionDescription: Message.CallOffer,  completion: @escaping (_ error: Error?) -> Void) {
        
        self.peerConnection?.close()
        self.peerConnection = Self.createPeerConnection()
        do {
            try self.configurePeerConnection()
        } catch {
            completion(error)
            return
        }

        let constrains = RTCMediaConstraints(mandatoryConstraints:[kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue],
                                             optionalConstraints: nil)
        
        let offerSdp = offerSessionDescription.rtcSessionDescription
        self.peerConnection!.setRemoteDescription(offerSdp) { error in
            if let error = error {
                completion(error)
                return
            }
            
            self.peerConnection!.answer(for: constrains) { localSDP, error in
                guard let answerSdp = localSDP else {
                    completion(error)
                    return
                }
                
                self.peerConnection!.setLocalDescription(answerSdp) { error in
                    if error == nil {
                        self.sendSignalingMessage(answer: answerSdp, completion: completion)
                    }

                    completion(error)
                }
            }
        }
    }
    
    func acceptAnswer(_ callAnswer: Message.CallAnswer,  completion: @escaping (_ error: Error?) -> Void) {
        let sdp = callAnswer.rtcSessionDescription
        self.peerConnection?.setRemoteDescription(sdp, completionHandler: completion)
    }
    
    func addIceCandidate(_ iceCandidate: Message.IceCandidate) {
        self.peerConnection?.add(iceCandidate.rtcIceCandidate)
    }

    func endCall() {
        self.peerConnection?.close()
        self.peerConnection = nil
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
    
    private func sendSignalingMessage(offer sdp: RTCSessionDescription, completion: @escaping (_ error: Error?) -> Void) {
        let callOffer = Message.CallOffer(from: sdp)
        let messageContent = Message.callOffer(callOffer)
        
        self.dataSource.messageSender.send(messageContent: messageContent, date: Date(), channel: self.dataSource.channel, completion: completion)
    }

    private func sendSignalingMessage(answer sdp: RTCSessionDescription, completion: @escaping (_ error: Error?) -> Void) {
        let callAnswer = Message.CallAnswer(from: sdp)
        let messageContent = Message.callAnswer(callAnswer)

        self.dataSource.messageSender.send(messageContent: messageContent, date: Date(), channel: self.dataSource.channel, completion: completion)
    }

    private func sendSignalingMessage(candidate rtcIceCandidate: RTCIceCandidate, completion: @escaping (_ error: Error?) -> Void) {
        let iceCandiadte = Message.IceCandidate(from: rtcIceCandidate)
        let messageContent = Message.iceCandidate(iceCandiadte)

        self.dataSource.messageSender.send(messageContent: messageContent, date: Date(), channel: self.dataSource.channel, completion: completion)
    }
}

extension CallChannel: RTCPeerConnectionDelegate {
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        Log.debug("peerConnection new signaling state: \(stateChanged.rawValue)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        Log.debug("peerConnection did add stream")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        Log.debug("peerConnection did remote stream")
    }
    
    public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        Log.debug("peerConnection should negotiate")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        if newState == .connected {
            self.delegate?.callChannel(connected: self)
        }
        Log.debug("peerConnection new connection state: \(newState)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        Log.debug("peerConnection new gathering state: \(newState)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        Log.debug("peerConnection new local candidate: \(candidate)")

        self.sendSignalingMessage(candidate: candidate) { error in
            if let error = error {
                Log.error("\(error)")
            }
        }
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        Log.debug("peerConnection did remove candidate(s)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        Log.debug("peerConnection did open data channel")
    }
}
