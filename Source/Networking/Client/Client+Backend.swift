//
//  Client+Backend.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/13/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import VirgilCrypto

extension Client {
    internal func makeAuthHeader(for identity: String) throws -> [String: String] {
        // FIXME: Client class should be independent from ethree existance
        let keyPair = try Virgil.ethree.localKeyStorage.retrieveKeyPair()

        // Will be sync ever
        let card = try Virgil.ethree.findUser(with: identity)
            .startSync()
            .get()

        let stringToSign = "\(card.identifier).\(Int(Date().timeIntervalSince1970))"

        guard let dataToSign = stringToSign.data(using: .utf8) else {
            throw Error.stringToDataFailed
        }

        let signature = try crypto.generateSignature(of: dataToSign, using: keyPair.privateKey)

        let authHeader = "Bearer " + stringToSign + "." + signature.base64EncodedString()

        return ["Authorization": authHeader]
    }

    public func getEjabberdToken(identity: String) throws -> String {
        let header = try self.makeAuthHeader(for: identity)

        let request = Request(url: URLConstants.ejabberdJwtEndpoint,
                              method: .get,
                              headers: header)

        let response = try self.connection.send(request)
            .startSync()
            .get()

        return try self.parse(response, for: "token")
    }

    public func getVirgilToken(identity: String) throws -> String {
        let header = try self.makeAuthHeader(for: identity)

        let request = Request(url: URLConstants.virgilJwtEndpoint,
                              method: .get,
                              headers: header)

        let response = try self.connection.send(request)
            .startSync()
            .get()

        return try self.parse(response, for: "token")
    }

    public func signUp(_ rawCard: RawSignedModel,
                       verifier: VirgilCardVerifier) throws -> Card {

          let exportedRawCard = try rawCard.exportAsJson()

          let headers = ["Content-Type": "application/json"]
          let params = ["raw_card": exportedRawCard]
          let body = try JSONSerialization.data(withJSONObject: params, options: [])

          let request = Request(url: URLConstants.signUpEndpoint,
                                method: .post,
                                headers: headers,
                                body: body)

          let response = try self.connection.send(request)
              .startSync()
              .get()

          let exportedCard: Any = try self.parse(response, for: "virgil_card")

          return try CardManager.importCard(fromJson: exportedCard,
                                            crypto: self.crypto,
                                            cardVerifier: verifier)
      }
}
