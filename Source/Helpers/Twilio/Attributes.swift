//
//  Attributes.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/8/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import Foundation

extension TwilioHelper {
    struct ChannelAttributes: Codable {
        let initiator: String
        let friendlyName: String?
        var members: [String]
        let type: ChannelType

        static func `import`(_ json: [String: Any]) throws -> ChannelAttributes {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])

            return try JSONDecoder().decode(ChannelAttributes.self, from: data)
        }

        func export() throws -> [String: Any] {
            let data = try JSONEncoder().encode(self)

            guard let result = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw NSError()
            }

            return result
        }
    }

    struct MessageAttributes: Codable {
        let type: MessageType
        let sessionId: Data?
        let identifier: String?

        static func `import`(_ json: [String: Any]) throws -> MessageAttributes {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])

            return try JSONDecoder().decode(MessageAttributes.self, from: data)
        }

        func export() throws -> [String: Any] {
            let data = try JSONEncoder().encode(self)

            guard let result = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw NSError()
            }

            return result
        }
    }
}
