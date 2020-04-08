//
//  Client+Authorization.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/13/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import VirgilCrypto

extension Client {
    internal func makeAuthHeader(for identity: String) throws -> [String: String] {
        let localKeyManager = try LocalKeyManager(identity: identity, crypto: self.crypto)

        let user = try localKeyManager.retrieveUserData()

        let stringToSign = "\(user.card.identifier).\(Int(Date().timeIntervalSince1970))"

        guard let dataToSign = stringToSign.data(using: .utf8) else {
            throw Error.stringToDataFailed
        }

        let signature = try crypto.generateSignature(of: dataToSign, using: user.keyPair.privateKey)

        let authHeader = "Bearer " + stringToSign + "." + signature.base64EncodedString()

        return ["Authorization": authHeader]
    }

    public func getEjabberdToken(identity: String) throws -> String {
        let header = try self.makeAuthHeader(for: identity)

        let backendHost: String = SharedDefaults.shared.get(.backendHost)!
        let url = URL(string: "https://\(backendHost)/ejabberd-jwt/")!

        let request = Request(url: url,
                              method: .get,
                              headers: header)

        let response = try self.connection.send(request)
            .startSync()
            .get()

        return try self.parse(response, for: "token")
    }

    public func getVirgilToken(identity: String) throws -> String {
        let header = try self.makeAuthHeader(for: identity)

        let backendHost: String = SharedDefaults.shared.get(.backendHost)!
        let url = URL(string: "https://\(backendHost)/virgil-jwt/")!

        let request = Request(url: url,
                              method: .get,
                              headers: header)

        let response = try self.connection.send(request)
            .startSync()
            .get()

        return try self.parse(response, for: "token")
    }

    public func signUp(identity: String,
                       keyPair: VirgilKeyPair,
                       verifier: VirgilCardVerifier,
                       backendHost: String) throws -> Card {
        let modelSigner = ModelSigner(crypto: self.crypto)
        let rawCard = try CardManager.generateRawCard(crypto: self.crypto,
                                                      modelSigner: modelSigner,
                                                      privateKey: keyPair.privateKey,
                                                      publicKey: keyPair.publicKey,
                                                      identity: identity)
        let exportedRawCard = try rawCard.exportAsJson()

        let headers = ["Content-Type": "application/json"]
        let params = ["raw_card": exportedRawCard]
        let body = try JSONSerialization.data(withJSONObject: params, options: [])

        let request = Request(url: URL(string: "https://\(backendHost)/signup/")!,
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
