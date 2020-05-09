//
//  EjabberdToken.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/30/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

class EjabberdToken {

    struct HeaderContent: Decodable {
        let algorithm: String

        private enum CodingKeys: String, CodingKey {
            case algorithm = "alg"
        }

        init(base64Url: String) throws {
            guard let data = Data(base64UrlEncoded: base64Url) else {
                throw Client.Error.invalidEjabberdToken
            }

            self = try JSONDecoder().decode(HeaderContent.self, from: data)
        }
    }

    struct BodyContent: Decodable {
        let identity: String
        let expiresAt: Date

        private enum CodingKeys: String, CodingKey {
            case identity = "jid"
            case expiresAt = "exp"
        }

        init(base64Url: String) throws {
            guard let data = Data(base64UrlEncoded: base64Url) else {
                throw Client.Error.invalidEjabberdToken
            }

            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .secondsSince1970

            self = try jsonDecoder.decode(BodyContent.self, from: data)
        }
    }

    let headerContent: HeaderContent
    let bodyContent: BodyContent
    let signature: String
    let stringRepresentation: String

    public init(_ string: String) throws {
        self.stringRepresentation = string

        let array = string.components(separatedBy: ".")

        guard array.count == 3 else {
            throw Client.Error.invalidEjabberdToken
        }

        let headerBase64Url = array[0]
        let bodyBase64Url = array[1]

        self.signature = array[2]
        self.headerContent = try HeaderContent(base64Url: headerBase64Url)
        self.bodyContent = try BodyContent(base64Url: bodyBase64Url)
    }

    public func isExpired() -> Bool {
        let currentDate = Date().addingTimeInterval(5)
        let expiresAt = self.bodyContent.expiresAt

        print("--------> currentDate = \(currentDate)")
        print("--------> expiresAt   = \(expiresAt)")

        return currentDate >= expiresAt
    }
}
