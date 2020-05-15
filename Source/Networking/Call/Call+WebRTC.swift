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

    func setupPeerConnection() {
        assert(self.peerConnection == nil)

        do {
            // Basic configuration
            let rtcConfig = RTCConfiguration()

            let publicStunIceServer = RTCIceServer(urlStrings: URLConstants.publicStunServers)

            let ejabberdToken = try Ejabberd.shared.getToken()

            let turnIceServer = RTCIceServer(urlStrings: URLConstants.ejabberdTurnServers, username: self.myName, credential: ejabberdToken)

            rtcConfig.iceServers = [publicStunIceServer, turnIceServer]
            rtcConfig.sdpSemantics = .unifiedPlan
            rtcConfig.continualGatheringPolicy = .gatherContinually

            let rtcConstraints = RTCMediaConstraints(mandatoryConstraints: nil,
                                                     optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue])

            let peerConnection = Self.peerConnectionFactory.peerConnection(with: rtcConfig, constraints: rtcConstraints, delegate: nil)

            // Audio
            let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
            let audioSource = Self.peerConnectionFactory.audioSource(with: audioConstrains)
            let audioTrack = Self.peerConnectionFactory.audioTrack(with: audioSource, trackId: "audio0")
            peerConnection.add(audioTrack, streamIds: ["stream"])

            peerConnection.delegate = self

            self.peerConnection = peerConnection
        } catch {
            Log.error(error, message: "Failed to create and configure peer connection.")
        }
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

        case .connected:
            self.createConnectedAt()
            self.connectionStatus = .connected

        case .completed:
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

// TODO: Move to the CallManager
extension Call : RTCAudioSessionDelegate {
    public func audioSessionDidBeginInterruption(_ session: RTCAudioSession) {
        Log.debug("WebRTC Audio Session: did begin interruption.")
    }

    public func audioSessionDidEndInterruption(_ session: RTCAudioSession, shouldResumeSession: Bool) {
        Log.debug("WebRTC Audio Session: did end interruption, should resume session: \(shouldResumeSession).")
    }

    public func audioSessionDidChangeRoute(_ session: RTCAudioSession, reason: AVAudioSession.RouteChangeReason, previousRoute: AVAudioSessionRouteDescription) {
        Log.debug("WebRTC Audio Session: did change route with reason \(reason.rawValue), previous route: \(previousRoute)")
    }

    public func audioSessionMediaServerTerminated(_ session: RTCAudioSession) {
        Log.debug("WebRTC Audio Session: media server terminated.")
    }

    public func audioSessionMediaServerReset(_ session: RTCAudioSession) {
        Log.debug("WebRTC Audio Session: media server reset.")
    }

    public func audioSession(_ session: RTCAudioSession, didChangeCanPlayOrRecord canPlayOrRecord: Bool) {
        Log.debug("WebRTC Audio Session: did change can play or record: \(canPlayOrRecord).")
    }

    public func audioSessionDidStartPlayOrRecord(_ session: RTCAudioSession) {
        Log.debug("WebRTC Audio Session: did start play or record.")
    }

    public func audioSessionDidStopPlayOrRecord(_ session: RTCAudioSession) {
        Log.debug("WebRTC Audio Session: did stop play or record.")
    }

    public func audioSession(_ audioSession: RTCAudioSession, didChangeOutputVolume outputVolume: Float) {
        Log.debug("WebRTC Audio Session: did change output volume: \(outputVolume).")
    }

    public func audioSession(_ audioSession: RTCAudioSession, didDetectPlayoutGlitch totalNumberOfGlitches: Int64) {
        Log.debug("WebRTC Audio Session: did detect playout glitch: \(totalNumberOfGlitches).")
    }

    public func audioSession(_ audioSession: RTCAudioSession, willSetActive active: Bool) {
        Log.debug("WebRTC Audio Session: will set active: \(active).")
    }

    public func audioSession(_ audioSession: RTCAudioSession, didSetActive active: Bool) {
        Log.debug("WebRTC Audio Session: did set active: \(active).")
    }

    public func audioSession(_ audioSession: RTCAudioSession, failedToSetActive active: Bool, error: Error) {
        Log.debug("WebRTC Audio Session: failed to set active: \(active).")
    }
}
