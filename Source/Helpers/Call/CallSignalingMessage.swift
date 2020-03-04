//
//  SignalingMessage.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 04.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import WebRTC

enum CallSignalingMessage {
    case sdp(CallSessionDescription)
    case iceCandidate(CallIceCandidate)
}

extension CallSignalingMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case type
        case payload
    }
    
    enum DecodeError: Error {
         case unknownType
     }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case String(describing: CallSessionDescription.self):
            let description = try container.decode(CallSessionDescription.self, forKey: .payload)

            self = .sdp(description)
        case String(describing: CallIceCandidate.self):
            let candidate = try container.decode(CallIceCandidate.self, forKey: .payload)
            
            self = .iceCandidate(candidate)
        default:
            throw DecodeError.unknownType
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .sdp(let sessionDescription):
            try container.encode(sessionDescription, forKey: .payload)
            
            let sessionDescriptionString = String(describing: CallSessionDescription.self)
            try container.encode(sessionDescriptionString, forKey: .type)
        case .iceCandidate(let iceCandidate):
            try container.encode(iceCandidate, forKey: .payload)
            
            let candidateString = String(describing: CallIceCandidate.self)
            try container.encode(candidateString, forKey: .type)
        }
    }
    
    static func `import`(from jsonString: String) throws -> CallSignalingMessage {
        let data = jsonString.data(using: .utf8)!
        
        return try JSONDecoder().decode(CallSignalingMessage.self, from: data)
    }
    
    func exportAsJsonString() throws -> String {
        let data = try JSONEncoder().encode(self)
        
        // FIXME: Change to other format
        return String(data: data, encoding: .utf8)!
    }
}
