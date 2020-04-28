//
//  Call+WebRTC.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 04.04.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import WebRTC

extension RTCIceConnectionState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .new:          return "new"
        case .checking:     return "checking"
        case .connected:    return "connected"
        case .completed:    return "completed"
        case .failed:       return "failed"
        case .disconnected: return "disconnected"
        case .closed:       return "closed"
        case .count:        return "count"
        @unknown default:   return "Unknown \(self.rawValue)"
        }
    }
}

extension RTCSignalingState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .stable:               return "stable"
        case .haveLocalOffer:       return "haveLocalOffer"
        case .haveLocalPrAnswer:    return "haveLocalPrAnswer"
        case .haveRemoteOffer:      return "haveRemoteOffer"
        case .haveRemotePrAnswer:   return "haveRemotePrAnswer"
        case .closed:               return "closed"
        @unknown default:   return "Unknown \(self.rawValue)"
        }
    }
}

extension RTCIceGatheringState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .new:          return "new"
        case .gathering:    return "gathering"
        case .complete:     return "complete"
        @unknown default:   return "Unknown \(self.rawValue)"
        }
    }
}

extension RTCDataChannelState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .connecting:   return "connecting"
        case .open:         return "open"
        case .closing:      return "closing"
        case .closed:       return "closed"
        @unknown default:   return "Unknown \(self.rawValue)"
        }
    }
}

// MARK: - RTCPeerConnection
extension Call {
    private static let peerConnectionFactory: RTCPeerConnectionFactory = RTCPeerConnectionFactory()

    static func createPeerConnection(username: String, credential: String, delegate: RTCPeerConnectionDelegate? = nil) throws -> RTCPeerConnection {
        // Basic configuration
        let rtcConfig = RTCConfiguration()

        let publicStunIceServer = RTCIceServer(urlStrings: URLConstants.publicStunServers)

        let turnIceServer = RTCIceServer(urlStrings: URLConstants.ejabberdTurnServers, username: username, credential: credential)

        rtcConfig.iceServers = [publicStunIceServer, turnIceServer]
        rtcConfig.sdpSemantics = .unifiedPlan
        rtcConfig.continualGatheringPolicy = .gatherContinually

        let rtcConstraints = RTCMediaConstraints(mandatoryConstraints: nil,
                                                 optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue])

        let peerConnection = self.peerConnectionFactory.peerConnection(with: rtcConfig, constraints: rtcConstraints, delegate: delegate)

        // Audio
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = Self.peerConnectionFactory.audioSource(with: audioConstrains)
        let audioTrack = Self.peerConnectionFactory.audioTrack(with: audioSource, trackId: "audio0")
        peerConnection.add(audioTrack, streamIds: ["stream"])

        // Audio session
        RTCAudioSession.sharedInstance().lockForConfiguration()
        try RTCAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord.rawValue)
        try RTCAudioSession.sharedInstance().setMode(AVAudioSession.Mode.voiceChat.rawValue)
        RTCAudioSession.sharedInstance().unlockForConfiguration()

        return peerConnection
    }
}

// MARK: - RTCPeerConnectionDelegate
extension Call: RTCPeerConnectionDelegate {
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        Log.debug("WebRTC: peerConnection new signaling state: \(stateChanged)")
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        Log.debug("WebRTC: peerConnection did add stream")
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        Log.debug("WebRTC: peerConnection did remote stream")
    }

    public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        Log.debug("WebRTC: peerConnection should negotiate")
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Log.debug("WebRTC: peerConnection new connection state: \(newState)")

        switch newState {
        case .new:
            self.connectionStatus = .new

        case .checking:
            self.connectionStatus = .negotiating

        case .connected, .completed:
            self.connectionStatus = .connected

        case .disconnected:
            self.connectionStatus = .disconnected

        case .failed:
            self.connectionStatus = .failed

        case .closed:
            self.connectionStatus = .closed

        case .count:
            break

        @unknown default:
            break
        }
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        Log.debug("WebRTC: peerConnection new gathering state: \(newState)")
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        Log.debug("WebRTC: did discover local candidate:\n    sdp = \(candidate.sdp)")

        let iceCandidate = NetworkMessage.IceCandidate(from: candidate, withId: self.uuid)

        self.signalingDelegate?.call(self, didCreateIceCandidate: iceCandidate)
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        Log.debug("WebRTC: did remove \(candidates.count) candidate(s)")
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        Log.debug("WebRTC: did open data channel (not supported yet)")
    }
}
