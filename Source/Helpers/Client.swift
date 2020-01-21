//
//  Client.swift
//  Morse
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
        case stringToDataFailed
        case noBody
        case invalidServerResponse
    }

    private let serviceErrorDomain: String = "ClientErrorDomain"

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

    private func makeAuthHeader(for identity: String) throws -> [String: String] {
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

    private func handleError(statusCode: Int, body: Data?) -> Swift.Error {
        if let body = body {
            if let rawServiceError = try? JSONDecoder().decode(RawServiceError.self, from: body) {
                if rawServiceError.code == 40001 || rawServiceError.code == 40002 {
                    return UserFriendlyError.usernameAlreadyUsed
                }
                
                return ServiceError(httpStatusCode: statusCode,
                                    rawServiceError: rawServiceError,
                                    errorDomain: self.serviceErrorDomain)
            }
            else if let string = String(data: body, encoding: .utf8) {
                return NSError(domain: self.serviceErrorDomain,
                               code: statusCode,
                               userInfo: [NSLocalizedDescriptionKey: string])
            }
        }

        return NSError(domain: self.serviceErrorDomain,
                       code: statusCode,
                       userInfo: [NSLocalizedDescriptionKey: "Unknown service error"])
    }

    private func validateResponse(_ response: Response) throws {
        guard 200..<300 ~= response.statusCode else {
            throw self.handleError(statusCode: response.statusCode, body: response.body)
        }
    }

    private func parse<T>(_ response: Response, for key: String) throws -> T {
        try self.validateResponse(response)

        guard let data = response.body else {
            throw Error.noBody
        }

        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
            let result = json[key] as? T else {
                throw Error.invalidServerResponse
        }

        return result
    }
}

// MARK: - Queries
extension Client {
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
}
