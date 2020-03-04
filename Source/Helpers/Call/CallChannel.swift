//
//  WebRTCChannel.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 04.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import WebRTC

public class CallChannel: NSObject {

    private static let factory: RTCPeerConnectionFactory = RTCPeerConnectionFactory()

    private let peerConnection: RTCPeerConnection
    private let audioSession =  RTCAudioSession.sharedInstance()
    private let dataSource: DataSource
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    @available(*, unavailable)
    override init() {
        fatalError("CallChannel:init is unavailable")
    }
    
    required init(dataSource: DataSource) {
        self.dataSource = dataSource
        self.peerConnection = Self.createPeerConnection()
        super.init()
        self.peerConnection.delegate = self
    }

    public func offer(completion: @escaping (_ error: Error?) -> Void) {
        let constrains = RTCMediaConstraints(mandatoryConstraints:[kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue],
                                             optionalConstraints: nil)
        self.peerConnection.offer(for: constrains) { (sdp, error) in
            guard let sdp = sdp else {
                completion(error)
                return
            }
            
            self.peerConnection.setLocalDescription(sdp, completionHandler: { (error) in
                if error == nil {
                    self.sendSignalingMessage(sdp, completion: completion)
                }
                
                completion(error)
            })
        }
    }

    private static func createPeerConnection() -> RTCPeerConnection {
        let iceServers = ["stun:stun.l.google.com:19302",
                          "stun:stun1.l.google.com:19302",
                          "stun:stun2.l.google.com:19302",
                          "stun:stun3.l.google.com:19302",
                          "stun:stun4.l.google.com:19302"]
        
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: iceServers)]
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil,
                                              optionalConstraints: ["DtlsSrtpKeyAgreement":kRTCMediaConstraintsValueTrue])
        
        return Self.factory.peerConnection(with: config, constraints: constraints, delegate: nil)
    }
    
    private func sendSignalingMessage(_ sdp: RTCSessionDescription, completion: @escaping (_ error: Error?) -> Void) {
        let message = CallSignalingMessage.sdp(CallSessionDescription(from: sdp))
        self.sendSignalingMessage(message: message, completion: completion)
    }
    
    private func sendSignalingMessage(candidate rtcIceCandidate: RTCIceCandidate, completion: @escaping (_ error: Error?) -> Void) {
        let message = CallSignalingMessage.iceCandidate(CallIceCandidate(from: rtcIceCandidate))
        self.sendSignalingMessage(message: message, completion: completion)
    }
    
    private func sendSignalingMessage(message: CallSignalingMessage, completion: @escaping (_ error: Error?) -> Void) {
        do {
            let jsonData = try self.encoder.encode(message)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            try self.dataSource.addTextMessage(jsonString)
            completion(nil)
        }
        catch {
            Log.error("\(error)")
            completion(error)
        }
    }

    private func configureAudioSession() {
        self.audioSession.lockForConfiguration()
        do {
            try self.audioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
            try self.audioSession.setMode(AVAudioSession.Mode.voiceChat.rawValue)
        } catch let error {
            Log.error("Error changeing AVAudioSession category: \(error)")
        }
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
        self.sendSignalingMessage(candidate: candidate) { (error) in
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
