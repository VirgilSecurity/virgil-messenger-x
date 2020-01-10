//
//  Client.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/14/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import VirgilCrypto
import VirgilE3Kit

public class Client {
    private let connection = HttpConnection()
    internal let crypto: VirgilCrypto

    enum Error: String, Swift.Error {
        case jsonParsingFailed
        case stringToDataFailed
        case gettingJWTFailed
    }

    init(crypto: VirgilCrypto) {
        self.crypto = crypto
    }

    func makeTokenCallback(identity: String) -> EThree.RenewJwtCallback {
        return { completion in
            do {
                let token = try self.getVirgilToken(identity: identity)

                completion(token, nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }

    func makeAccessTokenProvider(identity: String) -> AccessTokenProvider {
        return CachingJwtProvider(renewTokenCallback: { _, completion in
            let tokenCallback = self.makeTokenCallback(identity: identity)

            tokenCallback(completion)
        })
    }

    private func makeAuthHeader(cardId: String,
                                privateKey: VirgilPrivateKey) throws -> String {
        let stringToSign = "\(cardId).\(Int(Date().timeIntervalSince1970))"

        guard let dataToSign = stringToSign.data(using: .utf8) else {
            throw Error.stringToDataFailed
        }

        let signature = try crypto.generateSignature(of: dataToSign, using: privateKey)

        return "Bearer " + stringToSign + "." + signature.base64EncodedString()
    }
}

// MARK: - Queries
extension Client {
    public func searchCards(identities: [String],
                            selfIdentity: String,
                            verifier: VirgilCardVerifier) throws -> [Card] {
        let provider = self.makeAccessTokenProvider(identity: selfIdentity)

        let params = CardManagerParams(crypto: self.crypto, accessTokenProvider: provider, cardVerifier: verifier)
        let cardManager = CardManager(params: params)

        return try cardManager.searchCards(identities: identities).startSync().get()
    }

    public func signUp(identity: String,
                       keyPair: VirgilKeyPair,
                       verifier: VirgilCardVerifier) throws -> Card {
        let modelSigner = ModelSigner(crypto: self.crypto)
        let rawCard = try CardManager.generateRawCard(crypto: self.crypto,
                                                      modelSigner: modelSigner,
                                                      privateKey: keyPair.privateKey,
                                                      publicKey: keyPair.publicKey,
                                                      identity: identity)
        let exportedRawCard = try rawCard.exportAsJson()

        let requestURL = URLConstants.signUpEndpoint
        let headers = ["Content-Type": "application/json"]
        let params = ["rawCard": exportedRawCard]
        let body = try JSONSerialization.data(withJSONObject: params, options: [])

        let request = Request(url: requestURL, method: .post, headers: headers, body: body)

        let response = try self.connection.send(request).startSync().get()

        if let body = response.body,
            let text = String(data: body, encoding: .utf8),
            text == "Card with this identity already exists" {
            throw UserFriendlyError.usernameAlreadyUsed
        }

        guard let responseBody = response.body,
            let json = try JSONSerialization.jsonObject(with: responseBody, options: []) as? [String: Any] else {
                Log.error("Json parsing failed")
                throw Error.jsonParsingFailed
        }

        guard let exportedCard = json["virgil_card"] as? [String: Any] else {
            Log.error("Error while signing up: server didn't return card")
            throw UserFriendlyError.usernameAlreadyUsed
        }

        return try CardManager.importCard(fromJson: exportedCard,
                                          crypto: self.crypto,
                                          cardVerifier: verifier)
    }

    public func getEjabberdToken(identity: String) throws -> String {
        let localKeyManager = try LocalKeyManager(identity: identity, crypto: self.crypto)

        let user = try localKeyManager.retrieveUserData()

        let authHeader = try self.makeAuthHeader(cardId: user.card.identifier,
                                                 privateKey: user.keyPair.privateKey)

        let requestURL = URLConstants.ejabberdJwtEndpoint
        let headers = ["Content-Type": "application/json",
                       "Authorization": authHeader]

        let request = Request(url: requestURL, method: .get, headers: headers)
        let response = try self.connection.send(request).startSync().get()

        guard let responseBody = response.body,
            let tokenJson = try JSONSerialization.jsonObject(with: responseBody, options: []) as? [String: Any],
            let token = tokenJson["token"] as? String else {
                throw Error.jsonParsingFailed
        }

        return token
    }

    public func getVirgilToken(identity: String) throws -> String {
        let localKeyManager = try LocalKeyManager(identity: identity, crypto: self.crypto)

        let user = try localKeyManager.retrieveUserData()

        let authHeader = try self.makeAuthHeader(cardId: user.card.identifier, privateKey: user.keyPair.privateKey)

        let requestURL = URLConstants.virgilJwtEndpoint
        let headers = ["Content-Type": "application/json",
                       "Authorization": authHeader]

        let request = Request(url: requestURL, method: .get, headers: headers)
        let response = try self.connection.send(request).startSync().get()

        guard let responseBody = response.body,
            let tokenJson = try JSONSerialization.jsonObject(with: responseBody, options: []) as? [String: Any],
            let token = tokenJson["token"] as? String else {
                throw Error.jsonParsingFailed
        }

        return token
    }
}
