//
//  MessageContent.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/4/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

enum MessageContent {
    case text(TextContent)
    case sdp(CallSessionDescription)
    case iceCandidate(CallIceCandidate)
}

extension MessageContent: Codable {
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
        case String(describing: TextContent.self):
            let textContent = try container.decode(TextContent.self, forKey: .payload)
            
            self = .text(textContent)
        default:
            throw DecodeError.unknownType
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .sdp(let sessionDescription):
            let sessionDescriptionString = String(describing: CallSessionDescription.self)

            try container.encode(sessionDescriptionString, forKey: .type)
            try container.encode(sessionDescription, forKey: .payload)
        case .iceCandidate(let iceCandidate):
            let candidateString = String(describing: CallIceCandidate.self)
            
            try container.encode(candidateString, forKey: .type)
            try container.encode(iceCandidate, forKey: .payload)
        case .text(let textContent):
            let candidateString = String(describing: TextContent.self)
            
            try container.encode(candidateString, forKey: .type)
            try container.encode(textContent, forKey: .payload)
        }
    }
    
    static func `import`(from jsonString: String) throws -> MessageContent {
        let data = jsonString.data(using: .utf8)!
        
        return try JSONDecoder().decode(MessageContent.self, from: data)
    }
    
    func exportAsJsonString() throws -> String {
        let data = try JSONEncoder().encode(self)
        
        // FIXME: Change to other format
        return String(data: data, encoding: .utf8)!
    }
}
