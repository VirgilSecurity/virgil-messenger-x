//
//  Call.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 08.04.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import WebRTC

// MARK: - Public Types
public enum CallError: String, Error {
    case configurationFailed
    case connectionFailed
}

public enum CallState: String {
    case new // the call was initiated
    case calling // the call was initiated, but the caller is not available for now
    case ringing // the caller is hearing the call
    case accepted // the caller has been accepted the call
    case ended // call was ended
    case failed //
}

public enum CallConnectionStatus: String {
    case none // Connection was not initiated yet
    case new // the call was initiated
    case negotiating // esteblish connection parameters
    case connected // connection stable
    case disconnected // temporary disconnected
    case closed // connection was closed by one of the parties
    case failed // could not connect
}

// MARK: - Protocols
public protocol CallDelegate: class {
    func call(_ call: Call, didChangeState newState: CallState)
    func call(_ call: Call, didChangeConnectionStatus newConnectionStatus: CallConnectionStatus)
}

public protocol CallSignalingDelegate: class {
    func call(_ call: Call, didCreateOffer offer: NetworkMessage.CallOffer)
    func call(_ call: Call, didCreateAnswer answer: NetworkMessage.CallAnswer)
    func call(_ call: Call, didCreateUpdate update: NetworkMessage.CallUpdate)
    func call(_ call: Call, didCreateIceCandidate iceCandidate: NetworkMessage.IceCandidate)
    func call(_ call: Call, didFail error: Error)
}

// MARK: -
public class Call: NSObject {
    // MARK: Info properties
    public let uuid: UUID
    public let myName: String
    public let otherName: String

    // MARK: Delegates
    public weak var delegate: CallDelegate?
    private(set) weak var signalingDelegate: CallSignalingDelegate?

    // MARK: Connection properties
    private(set) var peerConnection: RTCPeerConnection?

    // MARK: Init / Reset
    init(withId uuid: UUID, myName: String, otherName: String, signalingTo signalingDelegate: CallSignalingDelegate? = nil) {
        self.uuid = uuid
        self.myName = myName
        self.otherName = otherName
        self.signalingDelegate = signalingDelegate
        self.state = .new
        self.connectionStatus = .none

        super.init()
    }

    // MARK: Info / State
    var state: CallState {
        didSet {
            self.delegate?.call(self, didChangeState: state)
        }
    }

    var connectionStatus: CallConnectionStatus {
        didSet {
            self.delegate?.call(self, didChangeConnectionStatus: connectionStatus)
        }
    }

    var isOutgoing: Bool {
        preconditionFailure("This property must be overridden")
    }

    // MARK: Configuration
    func setupPeerConnection() {
        precondition(self.peerConnection == nil, "Peer connection has been already setup")

        do {
            self.peerConnection = try Self.createPeerConnection(delegate: self)
        }
        catch {
            self.didFail(CallError.configurationFailed)
        }
    }

    // MARK: Call Management
    func end() {
        self.peerConnection?.close()
        self.peerConnection = nil
        self.state = .ended
    }

    func addRemoteIceCandidate(_ iceCandidate: NetworkMessage.IceCandidate) {
        let candidate = iceCandidate.rtcIceCandidate

        peerConnection?.add(candidate)

        Log.debug("WebRTC: did add remote candidate:\n    sdp = \(candidate.sdp)")
    }

    // MARK: Events
    func didCreateOffer(_ callOffer: NetworkMessage.CallOffer) {
        self.signalingDelegate?.call(self, didCreateOffer: callOffer)
    }

    func didCreateAnswer(_ callAnswer: NetworkMessage.CallAnswer) {
        self.signalingDelegate?.call(self, didCreateAnswer: callAnswer)
    }

    func didCreateIceCandidate(_ iceCandidate: NetworkMessage.IceCandidate) {
        self.signalingDelegate?.call(self, didCreateIceCandidate: iceCandidate)
    }

    func didFail(_ error: Error) {
        self.state = .failed
        self.signalingDelegate?.call(self, didFail: error)
    }
}
