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
    internal let connection = HttpConnection()
    internal let crypto: VirgilCrypto

    enum Error: String, Swift.Error {
        case stringToDataFailed
        case noBody
        case invalidServerResponse
        case inputStreamFromDownloadedFailed
        case inconsistencyState
        case selfCardNotFound
    }

    private let serviceErrorDomain: String = "ClientErrorDomain"

    public init(crypto: VirgilCrypto) {
        self.crypto = crypto
    }

    public func makeTokenCallback(identity: String) -> EThree.RenewJwtCallback {
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
    
    public func makePublishCardCallback(verifier: VirgilCardVerifier) -> EThree.PublishCardCallback {
        { rawCard in try self.signUp(rawCard, verifier: verifier) }
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

    internal func validateResponse(_ response: Response) throws {
        guard 200..<300 ~= response.statusCode else {
            throw self.handleError(statusCode: response.statusCode, body: response.body)
        }
    }

    internal func parse<T>(_ response: Response, for key: String) throws -> T {
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
