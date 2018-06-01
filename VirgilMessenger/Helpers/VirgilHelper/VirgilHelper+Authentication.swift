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
    func initializeAccount(withCardId cardId: String, identity: String, completion: @escaping (Error?) -> ()) {
        self.queue.async {
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
    }

    private func getTwilioToken(identity: String, completion: @escaping (String?, Error?) -> ()) {
        self.queue.async {
            guard let cardId = self.selfCard?.identifier else {
                Log.error("Missing self card")
                return
            }
            guard let privateKey = self.privateKey else {
                Log.error("Missing private key")
                return
            }
            let stringToSign = "\(cardId).\(Int(Date().timeIntervalSince1970))"

            guard let dataToSign = stringToSign.data(using: .utf8) else {
                Log.error("String to Data failed")
                return
            }
            guard let signature = try? self.crypto.generateSignature(of: dataToSign, using: privateKey) else {
                Log.error("Generating signature failed")
                return
            }
            let authHeader = "Bearer " + stringToSign + "." + signature.base64EncodedString()

            do {
                let requestForTwilioToken = try ServiceRequest(url: URL(string: self.twilioJwtEndpoint)!,
                                                               method: ServiceRequest.Method.post,
                                                               headers: ["Content-Type": "application/json",
                                                                         "Authorization": authHeader],
                                                               params: ["identity": identity])
                let responseWithTwilioToken = try self.connection.send(requestForTwilioToken)

                guard let responseWithTwilioTokenBody = responseWithTwilioToken.body,
                    let twilioTokenJson = try JSONSerialization.jsonObject(with: responseWithTwilioTokenBody, options: []) as? [String: Any],
                    let twilioToken = twilioTokenJson["token"] as? String
                    else {
                        throw VirgilHelperError.gettingTwilioTokenFailed
                }

                completion(twilioToken, nil)
            } catch {
                Log.error("Error while getting twilio token: \(error.localizedDescription)")
                completion(nil, error)
            }
        }
    }

    func setCardManager(identity: String) {
        guard let cardId = self.selfCard?.identifier else {
            Log.error("Missing self card")
            return
        }
        guard let privateKey = self.privateKey else {
            Log.error("Missing private key")
            return
        }
        let authHeader = "\(cardId).\(Int(Date().timeIntervalSince1970))"

        guard let dataToSign = authHeader.data(using: .utf8) else {
            Log.error("String to Data failed")
            return
        }
        guard let signature = try? self.crypto.generateSignature(of: dataToSign, using: privateKey) else {
            Log.error("Generating signature failed")
            return
        }
        let accessTokenProvider = CachingJwtProvider(renewTokenCallback: { tokenContext, completion in
            let jwtRequest = try? ServiceRequest(url: URL(string: self.virgilJwtEndpoint)!,
                                                 method: ServiceRequest.Method.post,
                                                 headers: ["Content-Type": "application/json",
                                                           "Authorization": "Bearer " + authHeader + "." + signature.base64EncodedString()],
                                                 params: ["identity": identity])
            guard let request = jwtRequest,
                let jwtResponse = try? self.connection.send(request),
                let responseBody = jwtResponse.body,
                let json = try? JSONSerialization.jsonObject(with: responseBody, options: []) as? [String: Any],
                let jwtStr = json?["token"] as? String else {
                    Log.error("Getting JWT failed")
                    completion(nil, VirgilHelperError.gettingJwtFailed)
                    return
            }
            completion(jwtStr, nil)
        })

        let cardCrypto = VirgilCardCrypto()
        guard let verifier = VirgilCardVerifier(cardCrypto: cardCrypto) else {
            Log.error("VirgilCardVerifier init failed")
            return
        }
        let params = CardManagerParams(cardCrypto: cardCrypto,
                                       accessTokenProvider: accessTokenProvider,
                                       cardVerifier: verifier)
        self.cardManager = CardManager(params: params)
    }
}
