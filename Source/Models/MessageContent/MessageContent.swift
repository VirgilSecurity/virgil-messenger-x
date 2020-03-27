//
//  MessageContent.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/6/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

enum MessageContent {
    case text(TextContent)
    case photo(PhotoContent)
    case voice(VoiceContent)
}

extension MessageContent: Codable {
    enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)

        switch type {
        case .text:
            let textContent = try container.decode(TextContent.self, forKey: .payload)
            
            self = .text(textContent)
        case .photo:
            let photoContent = try container.decode(PhotoContent.self, forKey: .payload)
            
            self = .photo(photoContent)
        case .voice:
            let voiceContent = try container.decode(VoiceContent.self, forKey: .payload)
            
            self = .voice(voiceContent)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let textContent):
            let type = MessageType.text
            
            try container.encode(type, forKey: .type)
            try container.encode(textContent, forKey: .payload)
        case .photo(let photoContent):
            let type = MessageType.photo
            
            try container.encode(type, forKey: .type)
            try container.encode(photoContent, forKey: .payload)
        case .voice(let voiceContent):
            let type = MessageType.voice
            
            try container.encode(type, forKey: .type)
            try container.encode(voiceContent, forKey: .payload)
        }
    }
    
    static func `import`(from data: Data) throws -> MessageContent {
        return try JSONDecoder().decode(MessageContent.self, from: data)
    }
    
    func exportAsJsonString() throws -> Data {
        return try JSONEncoder().encode(self)
    }
}

extension MessageContent {
    var notificationBody: String {
        switch self {
        case .text(let textContent):
            return textContent.body
        case .photo:
            return "📷 Photo"
        case .voice:
            return "🎤 Voice Message"
        }
    }
}
