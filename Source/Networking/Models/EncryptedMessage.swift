//
//  EncryptedMessage.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 03.01.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

public enum EncryptedMessageVersion: String, Codable, CaseIterable {
    case v1
    case v2
}

public enum PushType: String, Codable {
    case none
    case alert
    case voip
}

public enum EncryptedMessageError: Int, Error {
    case stringToDataFailed = 1
    case dataToStringFailed = 2
}

public class EncryptedMessage: Codable {
    let ciphertext: Data?
    let additionalData: AdditionalData?
    let date: Date

    var modelVersion: EncryptedMessageVersion {
        return self.version ?? .v1
    }

    var modelPushType: PushType {
        return self.pushType ?? .alert
    }

    private let version: EncryptedMessageVersion?
    private let pushType: PushType?

    public init(pushType: PushType, ciphertext: Data?, date: Date, additionalData: AdditionalData) {
        self.ciphertext = ciphertext
        self.date = date
        self.additionalData = additionalData
        self.version = EncryptedMessageVersion.allCases.last
        self.pushType = pushType
    }

    static func `import`(_ string: String) throws -> EncryptedMessage {
        guard let data = string.data(using: .utf8) else {
            throw EncryptedMessageError.stringToDataFailed
        }

        return try JSONDecoder().decode(EncryptedMessage.self, from: data)
    }

    func export() throws -> String {
        let data = try JSONEncoder().encode(self)

        guard let result = String(data: data, encoding: .utf8) else {
            throw EncryptedMessageError.dataToStringFailed
        }

        return result
    }
}
