//
//  MessageContent.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/2/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

struct MessageContent: Codable {
    let type: MessageType
    let body: String?
    let mediaHash: String?
    let mediaUrl: URL?
    
    init(body: String) {
        self.type = .text
        self.body = body
        self.mediaHash = nil
        self.mediaUrl = nil
    }
    
    init(type: MessageType, mediaHash: String, mediaUrl: URL) {
        self.type = type
        self.mediaHash = mediaHash
        self.mediaUrl = mediaUrl
        self.body = nil
    }
    
    static func `import`(_ string: String) throws -> MessageContent {
        guard let data = Data(base64Encoded: string) else {
            throw EncryptedMessageError.bodyIsNotBase64Encoded
        }

        return try JSONDecoder().decode(MessageContent.self, from: data)
    }

    func export() throws -> String {
        let data = try JSONEncoder().encode(self)

        return data.base64EncodedString()
    }
}
