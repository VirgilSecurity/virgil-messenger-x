//
//  VirgilHelper+Authentication.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/19/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation
import VirgilSDK
import VirgilCryptoApiImpl

extension VirgilHelper {
    /// Initializes Twilio SDK
    ///
    /// - Parameters:
    ///   - cardId: Virgil card identifier
    ///   - identity: identity of user
    ///   - completion: completion handler, called with error if failed
    func initializeTwilio(cardId: String, identity: String, completion: @escaping (Error?) -> ()) {
        self.getTwilioToken(identity: identity) { token, error in
            guard let token = token, error == nil else {
                completion(error)
                return
            }
            TwilioHelper.authorize(username: identity, device: "iPhone")
            TwilioHelper.sharedInstance.initialize(token: token) { error in
                completion(error)
            }
        }
    }

    func getTwilioToken(identity: String, completion: @escaping (String?, Error?) -> ()) {
        self.queue.async {
            guard let authHeader = self.makeAuthHeader() else {
                completion(nil, VirgilHelperError.gettingTwilioTokenFailed)
                return
            }

            do {
                let connection = HttpConnection()
                let requestURL = URL(string: self.twilioJwtEndpoint)!
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

                completion(token, nil)
            } catch {
                Log.error("Error while getting twilio token: \(error.localizedDescription)")
                completion(nil, error)
            }
        }
    }

    func setCardManager(identity: String) {
        let accessTokenProvider = CachingJwtProvider(renewTokenCallback: { tokenContext, completion in
            guard let authHeader = self.makeAuthHeader() else {
                completion(nil, VirgilHelperError.gettingJwtFailed)
                return
            }

            do {
                let connection = HttpConnection()
                let requestURL = URL(string: self.virgilJwtEndpoint)!
                let headers = ["Content-Type": "application/json",
                               "Authorization": authHeader]
                let params = ["identity": identity]
                let body = try JSONSerialization.data(withJSONObject: params, options: [])

                let request = Request(url: requestURL, method: .post, headers: headers, body: body)
                let response = try connection.send(request)

                guard let responseBody = response.body,
                    let tokenJson = try JSONSerialization.jsonObject(with: responseBody, options: []) as? [String: Any],
                    let token = tokenJson["token"] as? String else {
                        throw VirgilHelperError.gettingJwtFailed
                }

                completion(token, nil)
            } catch {
                completion(nil, VirgilHelperError.gettingJwtFailed)
            }
        })

        let cardCrypto = VirgilCardCrypto()
        guard let verifier = VirgilCardVerifier(cardCrypto: cardCrypto) else {
            Log.error("VirgilCardVerifier init failed")
            return
        }
        let params = CardManagerParams(cardCrypto: cardCrypto,
                                       accessTokenProvider: accessTokenProvider,
                                       cardVerifier: verifier)
        self.set(cardManager: CardManager(params: params))
    }

    /// Returns authentication header for requests to backend
    ///
    /// - Returns: string in CardId.Timestamp.Signature(CardId.Timestamp) format if succed, nil otherwise
    private func makeAuthHeader() -> String? {
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
