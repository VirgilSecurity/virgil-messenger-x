//
//  File.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/22/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

extension NetworkMessage: Codable {
    enum TypeCodingKeys: String, Codable {
        case text
        case photo
        case voice
        case callOffer = "call_offer"
        case callAnswer = "call_answer"
        case callUpdate = "call_update"
        case iceCandidate = "ice_candidate"
    }

    enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(TypeCodingKeys.self, forKey: .type)

        switch type {
        case .text:
            let text = try container.decode(Text.self, forKey: .payload)
            self = .text(text)

        case .photo:
            let photo = try container.decode(Photo.self, forKey: .payload)
            self = .photo(photo)

        case .voice:
            let voice = try container.decode(Voice.self, forKey: .payload)
            self = .voice(voice)

        case .callOffer:
            let callOffer = try container.decode(CallOffer.self, forKey: .payload)
            self = .callOffer(callOffer)

        case .callAnswer:
            let callAcceptedAnswer = try container.decode(CallAnswer.self, forKey: .payload)
            self = .callAnswer(callAcceptedAnswer)

        case .callUpdate:
            let callRejectedAnswer = try container.decode(CallUpdate.self, forKey: .payload)
            self = .callUpdate(callRejectedAnswer)

        case .iceCandidate:
            let iceCandidate = try container.decode(IceCandidate.self, forKey: .payload)
            self = .iceCandidate(iceCandidate)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let text):
            let type = TypeCodingKeys.text
            try container.encode(type, forKey: .type)
            try container.encode(text, forKey: .payload)

        case .photo(let photo):
            let type = TypeCodingKeys.photo
            try container.encode(type, forKey: .type)
            try container.encode(photo, forKey: .payload)

        case .voice(let voice):
            let type = TypeCodingKeys.voice
            try container.encode(type, forKey: .type)
            try container.encode(voice, forKey: .payload)

        case .callOffer(let callOffer):
            let type = TypeCodingKeys.callOffer
            try container.encode(type, forKey: .type)
            try container.encode(callOffer, forKey: .payload)

        case .callAnswer(let callAnswer):
            let type = TypeCodingKeys.callAnswer
            try container.encode(type, forKey: .type)
            try container.encode(callAnswer, forKey: .payload)

        case .callUpdate(let callRejectedAnswer):
            let type = TypeCodingKeys.callUpdate
            try container.encode(type, forKey: .type)
            try container.encode(callRejectedAnswer, forKey: .payload)

        case .iceCandidate(let iceCandidate):
            let type = TypeCodingKeys.iceCandidate
            try container.encode(type, forKey: .type)
            try container.encode(iceCandidate, forKey: .payload)
        }
    }

    static func `import`(from jsonData: Data) throws -> NetworkMessage {
        return try JSONDecoder().decode(NetworkMessage.self, from: jsonData)
    }

    func exportAsJsonData() throws -> Data {
        let data = try JSONEncoder().encode(self)
        return data
    }
}
