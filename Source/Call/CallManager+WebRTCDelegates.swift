//
//  CallManager+WebRTCDelegates.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 23.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import WebRTC

extension CallManager: RTCPeerConnectionDelegate {

    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        // This delegate is supperceeded by the delegate -
        //     peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState)
        Log.debug(#function + ": \(stateChanged.rawValue)")
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        Log.debug(#function)
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        // This is not called when RTCSdpSemanticsUnifiedPlan is specified.
        Log.debug(#function)
    }

    public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        Log.debug(#function)

        self.delegate?.callManagerLoseConnection(self)
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Log.debug(#function + " newState: \(newState)")

        switch newState {
        case .new, .checking:
            self.delegate?.callManagerIsConnecting(self)

        case .connected:
            self.delegate?.callManagerDidConnect(self)

        case .failed:
            self.delegate?.callManagerDidFail(self, error: nil)

        case .closed, .disconnected:
            // TODO: .disconnected can be recovered (need further investigation)
            self.delegate?.callManagerDidEndCall(self)

        case .completed, .count:
            break

        @unknown default:
            break
        }
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        Log.debug(#function + " newState: \(newState)")

        switch newState {
        case .new:
            break

        case .gathering:
            break

        case .complete:
            break

        @unknown default:
            break
        }
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        Log.debug(#function)

        self.sendSignalingMessage(candidate: candidate) { error in
            if let error = error {
                self.delegate?.callManagerDidFail(self, error: error)
                Log.error(error, message: "Send signaling message")
            }
        }
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        Log.debug(#function)
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        Log.debug(#function + " - Not supported operation")
    }
}
