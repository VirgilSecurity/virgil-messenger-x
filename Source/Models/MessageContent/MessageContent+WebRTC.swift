//
//  MessageContent+Text.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 13.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import WebRTC

extension MessageContent.CallOffer {
    init(from rtcSessionDescription: RTCSessionDescription) {
        assert(rtcSessionDescription.type == RTCSdpType.offer)
        self.sdp = rtcSessionDescription.sdp
    }
    
    var rtcSessionDescription: RTCSessionDescription {
        return RTCSessionDescription(type: RTCSdpType.offer, sdp: self.sdp)
    }
}

extension MessageContent.CallAnswer {
    init(from rtcSessionDescription: RTCSessionDescription) {
        assert(rtcSessionDescription.type == RTCSdpType.answer)
        self.sdp = rtcSessionDescription.sdp
    }

    var rtcSessionDescription: RTCSessionDescription {
        return RTCSessionDescription(type: RTCSdpType.answer, sdp: self.sdp)
    }
}

extension MessageContent.IceCandidate {
    init(from iceCandidate: RTCIceCandidate) {
        self.sdpMLineIndex = iceCandidate.sdpMLineIndex
        self.sdpMid = iceCandidate.sdpMid
        self.sdp = iceCandidate.sdp
    }
    
    var rtcIceCandidate: RTCIceCandidate {
        return RTCIceCandidate(sdp: self.sdp, sdpMLineIndex: self.sdpMLineIndex, sdpMid: self.sdpMid)
    }
}