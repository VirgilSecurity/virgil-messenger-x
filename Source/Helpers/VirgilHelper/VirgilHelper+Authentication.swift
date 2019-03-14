//
//  VirgilHelper+Authentication.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/19/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation
import VirgilSDK
import VirgilCrypto

extension VirgilHelper {
    func makeInitTwilioOperation(cardId: String, identity: String) -> GenericOperation<Void> {
        return CallbackOperation { _, completion in
            guard let authHeader = self.makeAuthHeader() else {
                completion(nil, VirgilHelperError.gettingTwilioTokenFailed)
                return
            }

            do {
                let connection = HttpConnection()
                let requestURL = URLConstansts.twilioJwtEndpoint
                let headers = ["Content-Type": "application/json",
                               "Authorization": authHeader]
                let params = ["identity": identity]
                let body = try JSONSerialization.data(withJSONObject: params, options: [])

                let request = Request(url: requestURL, method: .post, headers: headers, body: body)
                let response = try connection.send(request)

                guard let responseBody = response.body,
                    let tokenJson = try JSONSerialization.jsonObject(with: responseBody, options: []) as? [String: Any],
                    let token = tokenJson["token"] as? String else {
                        throw VirgilHelperError.gettingTwilioTokenFailed
                }

                TwilioHelper.authorize(username: identity, device: "iPhone")
                TwilioHelper.sharedInstance.initialize(token: token) { error in
                    if let error = error {
                        completion(nil, error)
                    } else {
                        completion((), error)
                    }
                }
            } catch {
                Log.error("Error while getting twilio token: \(error.localizedDescription)")
                completion(nil, error)
            }
        }
    }

    func getTwilioToken(identity: String, completion: @escaping (String?, Error?) -> ()) {
        self.queue.async {

        }
    }

    func setCardManager(identity: String) throws -> CardManager {
        let accessTokenProvider = self.makeAccessTokenProvider(identity: identity)

        let cardCrypto = VirgilCardCrypto(virgilCrypto: self.crypto)

        guard let verifier = VirgilCardVerifier(cardCrypto: cardCrypto) else {
            throw VirgilHelperError.cardVerifierInitFailed
        }

        let params = CardManagerParams(cardCrypto: cardCrypto,
                                       accessTokenProvider: accessTokenProvider,
                                       cardVerifier: verifier)
        let cardManager = CardManager(params: params)

        self.set(cardManager: cardManager)

        return cardManager
    }

    /// Returns authentication header for requests to backend
    ///
    /// - Returns: string in CardId.Timestamp.Signature(CardId.Timestamp) format if succed, nil otherwise
    func makeAuthHeader() -> String? {
        guard let cardId = self.selfCard?.identifier else {
            Log.error("Missing self card")
            return nil
        }
        let stringToSign = "\(cardId).\(Int(Date().timeIntervalSince1970))"

        guard let dataToSign = stringToSign.data(using: .utf8) else {
            Log.error("String to Data failed")
            return nil
        }

        guard let privateKey = self.privateKey else {
            Log.error("Missing private key")
            return nil
        }

        guard let signature = try? self.crypto.generateSignature(of: dataToSign, using: privateKey) else {
            Log.error("Generating signature failed")
            return nil
        }

        return "Bearer " + stringToSign + "." + signature.base64EncodedString()
    }
}
