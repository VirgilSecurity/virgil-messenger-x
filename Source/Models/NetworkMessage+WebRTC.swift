//
//  NetworkMessage+WebRTC.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 13.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import WebRTC

extension NetworkMessage.CallOffer {
    init(from rtcSessionDescription: RTCSessionDescription, caller: String) {
        assert(rtcSessionDescription.type == RTCSdpType.offer)

        self.callUUID = UUID()
        self.caller = caller
        self.sdp = rtcSessionDescription.sdp
    }

    var rtcSessionDescription: RTCSessionDescription {
        return RTCSessionDescription(type: RTCSdpType.offer, sdp: self.sdp)
    }
}

extension NetworkMessage.CallAnswer {
    init(from rtcSessionDescription: RTCSessionDescription, withId callUUID: UUID) {
        assert(rtcSessionDescription.type == RTCSdpType.answer)
        self.callUUID = callUUID
        self.sdp = rtcSessionDescription.sdp
    }

    var rtcSessionDescription: RTCSessionDescription {
        return RTCSessionDescription(type: RTCSdpType.answer, sdp: self.sdp)
    }
}

extension NetworkMessage.IceCandidate {
    init(from iceCandidate: RTCIceCandidate, withId callUUID: UUID) {
        self.callUUID = callUUID
        self.sdpMLineIndex = iceCandidate.sdpMLineIndex
        self.sdpMid = iceCandidate.sdpMid
        self.sdp = iceCandidate.sdp
    }

    var rtcIceCandidate: RTCIceCandidate {
        return RTCIceCandidate(sdp: self.sdp, sdpMLineIndex: self.sdpMLineIndex, sdpMid: self.sdpMid)
    }
}
