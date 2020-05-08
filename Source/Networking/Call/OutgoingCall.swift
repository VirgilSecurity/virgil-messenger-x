//
//  OutgoingCall.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 09.04.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import WebRTC

public class OutgoingCall: Call {

    // MARK: Init
    public init(withId uuid: UUID, from myName: String, to otherName: String, signalingTo signalingDelegate: CallSignalingDelegate? = nil) {
        super.init(withId: uuid, myName: myName, otherName: otherName, signalingTo: signalingDelegate)
    }

    // MARK: Info
    override var isOutgoing: Bool {
        return true
    }

    // MARK: Call management
    public func start(_ completion: @escaping (Error?) -> Void) {
        self.state = .new

        self.setupPeerConnection()

        guard let peerConnection = self.peerConnection else {
            completion(CallError.configurationFailed)
            return
        }

        self.state = .calling

        let constrains = RTCMediaConstraints(mandatoryConstraints: [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue],
                                             optionalConstraints: nil)

        peerConnection.offer(for: constrains) { sdp, error in
            guard let sdp = sdp else {
                completion(CallError.configurationFailed)
                return
            }

            peerConnection.setLocalDescription(sdp) { error in
                guard let error = error else {
                    let callOffer = NetworkMessage.CallOffer(callUUID: self.uuid, date: Date(), caller: self.myName, sdp: sdp.sdp)

                    self.didCreateOffer(callOffer)
                    completion(nil)
                    return
                }

                Log.error(error, message: "Failed to set local session description")

                completion(CallError.configurationFailed)
            }
        }
    }

    public func accept(_ callAnswer: NetworkMessage.CallAnswer) {

        if (callAnswer.callUUID != self.uuid) {
            self.didFail(CallInternalError.uuidMismatch)
            return
        }

        guard let peerConnection = self.peerConnection else {
            self.didFail(CallInternalError.noPeerConnection)
            return
        }

        self.state = .accepted

        let sdp = callAnswer.rtcSessionDescription
        peerConnection.setRemoteDescription(sdp) { error in
            guard let error = error else {
                return
            }

            Log.error(error, message: "Failed to set an offer session description as remote session description")

            self.didFail(CallError.configurationFailed)
        }
    }

    public func remoteDidAcceptCall() {
        self.state = .ringing
    }
}
