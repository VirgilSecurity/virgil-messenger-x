//
//  WebRTCChannel.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 04.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import WebRTC
import XMPPFrameworkSwift

public class CallChannel: NSObject {

    private static let factory: RTCPeerConnectionFactory = RTCPeerConnectionFactory()

    private let audioSession =  RTCAudioSession.sharedInstance()
    
    private let peerConnection: RTCPeerConnection
    private let dataSource: DataSource
    
    required init(dataSource: DataSource) {
        self.dataSource = dataSource
        self.peerConnection = Self.createPeerConnection()
        
        super.init()
        
        self.peerConnection.delegate = self
    }

    public func offer(completion: @escaping (_ error: Error?) -> Void) {
        let constrains = RTCMediaConstraints(mandatoryConstraints:[kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue],
                                             optionalConstraints: nil)
        
        self.peerConnection.offer(for: constrains) { sdp, error in
            guard let sdp = sdp else {
                completion(error)
                return
            }
            
            self.peerConnection.setLocalDescription(sdp) { error in
                if error == nil {
                    self.sendSignalingMessage(sdp, completion: completion)
                }
                
                completion(error)
            }
        }
    }

    private static func createPeerConnection() -> RTCPeerConnection {
        // TODO: Move to Constants
        let iceServers = ["stun:stun.l.google.com:19302",
                          "stun:stun1.l.google.com:19302",
                          "stun:stun2.l.google.com:19302",
                          "stun:stun3.l.google.com:19302",
                          "stun:stun4.l.google.com:19302"]
        
        let config = RTCConfiguration()
        
        let rtcIceServer = RTCIceServer(urlStrings: iceServers)
        config.iceServers = [rtcIceServer]
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil,
                                              optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue])
        
        return self.factory.peerConnection(with: config, constraints: constraints, delegate: nil)
    }
    
    private func sendSignalingMessage(_ sdp: RTCSessionDescription, completion: @escaping (_ error: Error?) -> Void) {
        let sessionDescription = CallSessionDescription(from: sdp)
        let message = CallSignalingMessage.sdp(sessionDescription)

        self.sendSignalingMessage(message: message, completion: completion)
    }
    
    private func sendSignalingMessage(candidate rtcIceCandidate: RTCIceCandidate, completion: @escaping (_ error: Error?) -> Void) {
        let callIceCandidate = CallIceCandidate(from: rtcIceCandidate)
        let message = CallSignalingMessage.iceCandidate(callIceCandidate)
        
        self.sendSignalingMessage(message: message, completion: completion)
    }
    
    private func sendSignalingMessage(message: CallSignalingMessage, completion: @escaping (_ error: Error?) -> Void) {
        do {
            let jsonString = try message.exportAsJsonString()
            
            let type: XMPPMessage.MessageType
            
            switch message {
            case .sdp:
                type = .voiceSdp
            case .iceCandidate:
                type = .voiceIce
            }

            try self.dataSource.addTextMessage(jsonString, type: type)
            
            completion(nil)
        }
        catch {
            Log.error("\(error)")
            completion(error)
        }
    }

    private func configureAudioSession() throws {
        self.audioSession.lockForConfiguration()
        
        try self.audioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
        try self.audioSession.setMode(AVAudioSession.Mode.voiceChat.rawValue)
        
        self.audioSession.unlockForConfiguration()
    }
}

extension CallChannel: RTCPeerConnectionDelegate {
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        Log.debug("peerConnection new signaling state: \(stateChanged)")
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
