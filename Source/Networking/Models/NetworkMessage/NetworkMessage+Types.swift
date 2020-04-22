//
//  NetworkMessageTypes.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/22/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

// TODO: Move to proper place
public enum CallUpdateAction: String, Codable {
    case received
    case end
}

extension NetworkMessage {
    public struct Text: Codable {
        let body: String
    }

    public struct Photo: Codable {
        let identifier: String
        let url: URL
    }

    public struct Voice: Codable {
        let identifier: String
        let duration: TimeInterval
        let url: URL
    }

    public struct CallOffer: Codable {
        let callUUID: UUID
        let date: Date
        let caller: String
        let sdp: String
    }

    public struct CallAnswer: Codable {
        let callUUID: UUID
        let sdp: String
    }

    public struct CallUpdate: Codable {
        let callUUID: UUID
        let action: CallUpdateAction
    }

    public struct IceCandidate: Codable {
        let callUUID: UUID
        let sdp: String
        let sdpMLineIndex: Int32
        let sdpMid: String?
    }
}
