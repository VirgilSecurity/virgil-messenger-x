//
//  Client.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/14/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import Foundation
import VirgilSDK
import VirgilCrypto

enum ClientError: String, Error {
    case jsonParsingFailed
    case stringToDataFailed
    case gettingJWTFailed
}

class Client {
    private let connection = HttpConnection()
    private let crypto: VirgilCrypto
    private let cardCrypto: VirgilCardCrypto

    init(crypto: VirgilCrypto, cardCrypto: VirgilCardCrypto) {
        self.crypto = crypto
        self.cardCrypto = cardCrypto
    }

    func makeAccessTokenProvider(identity: String,
                                 cardId: String,
                                 privateKey: VirgilPrivateKey) -> AccessTokenProvider {
        let accessTokenProvider = CachingJwtProvider(renewTokenCallback: { _, completion in
            do {
                let token = try self.getVirgilToken(identity: identity,
                                                    cardId: cardId,
                                                    privateKey: privateKey)
                completion(token, nil)
            } catch {
                completion(nil, error)
            }
        })

        return accessTokenProvider
    }

    private func makeAuthHeader(cardId: String,
                                privateKey: VirgilPrivateKey) throws -> String {
        let stringToSign = "\(cardId).\(Int(Date().timeIntervalSince1970))"

        guard let dataToSign = stringToSign.data(using: .utf8) else {
            throw ClientError.stringToDataFailed
        }

        let signature = try crypto.generateSignature(of: dataToSign, using: privateKey)

        return "Bearer " + stringToSign + "." + signature.base64EncodedString()
    }
}

// MARK: - Queries
extension Client {
    func signUp(identity: String,
                keyPair: VirgilKeyPair,
                verifier: VirgilCardVerifier) throws -> Card {
        let modelSigner = ModelSigner(cardCrypto: self.cardCrypto)
        let rawCard = try CardManager.generateRawCard(cardCrypto: self.cardCrypto,
                                                      modelSigner: modelSigner,
                                                      privateKey: keyPair.privateKey,
                                                      publicKey: keyPair.publicKey,
                                                      identity: identity)
        let exportedRawCard = try rawCard.exportAsJson()

        let requestURL = URLConstansts.signUpEndpoint
        let headers = ["Content-Type": "application/json"]
        let params = ["rawCard" : exportedRawCard]
        let body = try JSONSerialization.data(withJSONObject: params, options: [])

        let request = Request(url: requestURL, method: .post, headers: headers, body: body)

        let response = try self.connection.send(request)

        if let body = response.body,
            let text = String(data: body, encoding: .utf8),
            text == "Card with this identity already exists" {
            throw VirgilHelper.UserFriendlyError.usernameAlreadyUsed
        }

        guard let responseBody = response.body,
            let json = try JSONSerialization.jsonObject(with: responseBody, options: []) as? [String: Any] else {
                Log.error("Json parsing failed")
                throw ClientError.jsonParsingFailed
        }

        guard let exportedCard = json["virgil_card"] as? [String: Any] else {
            Log.error("Error while signing up: server didn't return card")
            throw VirgilHelper.UserFriendlyError.usernameAlreadyUsed
        }

        return try CardManager.importCard(fromJson: exportedCard,
                                          cardCrypto: cardCrypto,
                                          cardVerifier: verifier)
    }

    func getTwilioToken(identity: String,
                        cardId: String,
                        crypto: VirgilCrypto,
                        privateKey: VirgilPrivateKey) throws -> String {
        let authHeader = try self.makeAuthHeader(cardId: cardId, privateKey: privateKey)

        let requestURL = URLConstansts.twilioJwtEndpoint
        let headers = ["Content-Type": "application/json",
                       "Authorization": authHeader]
        let params = ["identity": identity]
        let body = try JSONSerialization.data(withJSONObject: params, options: [])

        let request = Request(url: requestURL, method: .post, headers: headers, body: body)
        let response = try self.connection.send(request)

        guard let responseBody = response.body,
            let tokenJson = try JSONSerialization.jsonObject(with: responseBody, options: []) as? [String: Any],
            let token = tokenJson["token"] as? String else {
                throw ClientError.jsonParsingFailed
        }

        return token
    }

    func getVirgilToken(identity: String,
                        cardId: String,
                        privateKey: VirgilPrivateKey) throws -> String {
        let authHeader = try self.makeAuthHeader(cardId: cardId, privateKey: privateKey)

        let requestURL = URLConstansts.virgilJwtEndpoint
        let headers = ["Content-Type": "application/json",
                       "Authorization": authHeader]
        let params = ["identity": identity]
        let body = try JSONSerialization.data(withJSONObject: params, options: [])

        let request = Request(url: requestURL, method: .post, headers: headers, body: body)
        let response = try self.connection.send(request)

        guard let responseBody = response.body,
            let tokenJson = try JSONSerialization.jsonObject(with: responseBody, options: []) as? [String: Any],
            let token = tokenJson["token"] as? String else {
                throw ClientError.jsonParsingFailed
        }

        return token
    }
}
