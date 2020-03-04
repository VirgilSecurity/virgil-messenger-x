//
//  CallSignalingMessage.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 04.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import WebRTC

/// This enum is a swift wrapper over `RTCSdpType` for easy encode and decode
enum SdpType: String, Codable {
    case offer
    case prAnswer
    case answer
    
    var rtcSdpType: RTCSdpType {
        switch self {
        case SdpType.offer:    return RTCSdpType.offer
        case SdpType.answer:   return RTCSdpType.answer
        case SdpType.prAnswer: return RTCSdpType.prAnswer
        }
    }
}

/// This struct is a swift wrapper over `RTCSessionDescription` for easy encode and decode
struct CallSessionDescription: Codable {
    let sdp: String
    let type: SdpType
    
    init(from rtcSessionDescription: RTCSessionDescription) {
        self.sdp = rtcSessionDescription.sdp
        
        switch rtcSessionDescription.type {
        case RTCSdpType.offer:    self.type = SdpType.offer
        case RTCSdpType.prAnswer: self.type = SdpType.prAnswer
        case RTCSdpType.answer:   self.type = SdpType.answer
        @unknown default:
            fatalError("Unknown RTCSessionDescription type: \(rtcSessionDescription.type.rawValue)")
        }
    }
    
    var rtcSessionDescription: RTCSessionDescription {
        return RTCSessionDescription(type: self.type.rtcSdpType, sdp: self.sdp)
    }
}
