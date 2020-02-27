//
//  EncryptedMessage.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 03.01.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import XMPPFrameworkSwift
import VirgilSDK

public enum EncryptedMessageError: Int, Error {
    case bodyIsNotBase64Encoded = 1
}

public class EncryptedMessage: Codable {
    let ciphertext: String
    let date: Date

    public init(ciphertext: String, date: Date) {
        self.ciphertext = ciphertext
        self.date = date
    }
    
    static func `import`(_ string: String) throws -> EncryptedMessage {
        guard let data = Data(base64Encoded: string) else {
            throw EncryptedMessageError.bodyIsNotBase64Encoded
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(DateUtils.timestampDateDecodingStrategy)

        return try decoder.decode(EncryptedMessage.self, from: data)
    }

    func export() throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom(DateUtils.timestampDateEncodingStrategy)

        return try encoder.encode(self).base64EncodedString()
    }
}
