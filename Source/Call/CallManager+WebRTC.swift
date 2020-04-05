//
//  CallManager+WebRTC.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 04.04.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
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

extension CallManager: RTCPeerConnectionDelegate {
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
        
        self.connectionStatus = .negotiating
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
            self.connectionStatus = .failed(CallManagerError.connectionFailed)

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

        self.sendSignalingMessage(candidate: candidate) { error in
            if let error = error {
                self.connectionStatus = .failed(error)
            }
        }
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        Log.debug("WebRTC: did remove \(candidates.count) candidate(s)")
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        Log.debug("WebRTC: did open data channel (not supported yet)")
    }
}
