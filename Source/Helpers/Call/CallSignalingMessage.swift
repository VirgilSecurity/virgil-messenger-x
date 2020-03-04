//
//  SignalingMessage.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 04.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import WebRTC

enum CallSignalingMessage {
    case sdp(CallSessionDescription)
    case iceCandidate(CallIceCandidate)
}

extension CallSignalingMessage: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case String(describing: CallSessionDescription.self):
            self = .sdp(try container.decode(CallSessionDescription.self, forKey: .payload))
        case String(describing: CallIceCandidate.self):
            self = .iceCandidate(try container.decode(CallIceCandidate.self, forKey: .payload))
        default:
            throw DecodeError.unknownType
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .sdp(let sessionDescription):
            try container.encode(sessionDescription, forKey: .payload)
            try container.encode(String(describing: CallSessionDescription.self), forKey: .type)
        case .iceCandidate(let iceCandidate):
            try container.encode(iceCandidate, forKey: .payload)
            try container.encode(String(describing: CallIceCandidate.self), forKey: .type)
        }
    }
    
    enum DecodeError: Error {
        case unknownType
    }
    
    enum CodingKeys: String, CodingKey {
        case type, payload
    }
}
