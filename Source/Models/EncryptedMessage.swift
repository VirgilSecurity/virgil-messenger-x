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

public enum EncryptedMessageError: Int, Error {
    case bodyIsNotBase64Encoded = 1
}

public class EncryptedMessage: Codable {
    let ciphertext: Data
    let additionalData: Data?
    let date: Date
    
    var modelVersion: EncryptedMessageVersion {
        return self.version ?? .v1
    }
    
    private let version: EncryptedMessageVersion?

    public init(ciphertext: Data, date: Date, additionalData: Data?) {
        self.ciphertext = ciphertext
        self.date = date
        self.additionalData = additionalData
        self.version = EncryptedMessageVersion.allCases.last
    }
    
    static func `import`(_ string: String) throws -> EncryptedMessage {
        guard let data = Data(base64Encoded: string) else {
            throw EncryptedMessageError.bodyIsNotBase64Encoded
        }

        return try JSONDecoder().decode(EncryptedMessage.self, from: data)
    }

    func export() throws -> String {
        let data = try JSONEncoder().encode(self)

        return data.base64EncodedString()
    }
}
