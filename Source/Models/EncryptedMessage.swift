//
//  EncryptedMessage.swift
//  Morse
//
//  Created by Yevhen Pyvovarov on 03.01.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import XMPPFrameworkSwift

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

    static func `import`(_ message: XMPPMessage) throws -> EncryptedMessage {
        let body = try message.getBody()

        guard let data = Data(base64Encoded: body) else {
            throw EncryptedMessageError.bodyIsNotBase64Encoded
        }

        return try JSONDecoder().decode(EncryptedMessage.self, from: data)
    }

    func export() throws -> String {
        let data = try JSONEncoder().encode(self)

        return data.base64EncodedString()
    }
}
