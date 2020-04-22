//
//  NetworkMessage.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/6/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

public enum NetworkMessage {
    case text(Text)
    case photo(Photo)
    case voice(Voice)
    case callOffer(CallOffer)
    case callAnswer(CallAnswer)
    case callUpdate(CallUpdate)
    case iceCandidate(IceCandidate)
}

extension NetworkMessage {
    var notificationBody: String {
        switch self {
        case .text(let text):
            return text.body
        case .photo:
            return "📷 Photo"
        case .voice:
            return "🎤 Voice Message"
        case .callOffer, .callAnswer, .callUpdate, .iceCandidate:
            // For this messages notifications are not produced
            return ""
        }
    }
}
