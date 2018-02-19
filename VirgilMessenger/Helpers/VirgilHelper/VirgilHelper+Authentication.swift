//
//  VirgilHelper+Authentication.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/19/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation

extension VirgilHelper {
    func initializeAccount(withCardId cardId: String, identity: String, completion: @escaping (Error?) -> ()) {
        self.queue.async {
            do {
                let virgilToken = try self.getVirgilToken(withCardId: cardId, identity: identity)

                self.getTwilioToken(virgilToken: virgilToken) { token, error in
                    guard let token = token, error == nil else {
                        completion(error)
                        return
                    }
                    TwilioHelper.authorize(username: identity, device: "iPhone")
                    TwilioHelper.sharedInstance.initialize(token: token) { error in
                        completion(error)
                    }
                }
            } catch {
                completion(VirgilHelperError.gettingVirgilTokenFailed)
                return
            }
        }
    }

    private func getTwilioToken(virgilToken: String, completion: @escaping (String?, Error?) -> ()) {
        self.queue.async {
            do {
                let virgilToken = "bearer " + virgilToken
                let requestForTwilioToken = try ServiceRequest(url: URL(string: self.twilioServer + "v1/tokens/twilio")!, method: ServiceRequest.Method.get, headers: ["Authorization": virgilToken])
                let responseWithTwilioToken = try self.connection.send(requestForTwilioToken)

                guard let responseWithTwilioTokenBody = responseWithTwilioToken.body,
                    let twilioTokenJson = try JSONSerialization.jsonObject(with: responseWithTwilioTokenBody, options: []) as? [String: Any],
                    let twilioToken = twilioTokenJson["twilioToken"] as? String
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

    private func getVirgilToken(withCardId: String, identity: String) throws -> String {
        let requestForGrantId = try ServiceRequest(url: URL(string: self.authServer + "v4/authorization-grant/actions/get-challenge-message")!, method: ServiceRequest.Method.post, headers: ["Content-Type":"application/json"], params: ["resource_owner_virgil_card_id" : withCardId])

        let responseWithGrantId = try self.connection.send(requestForGrantId)

        let entry = try self.keyStorage.loadKeyEntry(withName: identity)

        guard let responseWithGrantIdBody = responseWithGrantId.body,
            let jsonWithGrantId = try JSONSerialization.jsonObject(with: responseWithGrantIdBody, options: []) as? [String: Any],
            let encryptedMessage = jsonWithGrantId["encrypted_message"] as? String,
            let authGrantId = jsonWithGrantId["authorization_grant_id"] as? String,
            let data = Data(base64Encoded: encryptedMessage),
            let privateKey = self.crypto.importPrivateKey(from: entry.value),
            let authPublicKeyData = Data(base64Encoded: self.authPublicKey),
            let importedPublicKey = self.crypto.importPublicKey(from: authPublicKeyData)
            else {
                throw VirgilHelperError.gettingVirgilTokenFailed
        }

        let decodedMessage = try self.crypto.decrypt(data, with: privateKey)

        let newEncryptedMessage = try self.crypto.encrypt(decodedMessage, for: [importedPublicKey])
        let message = newEncryptedMessage.base64EncodedString()

        let requestForCode = try ServiceRequest(url: URL(string: self.authServer + "v4/authorization-grant/" + authGrantId + "/actions/acknowledge")!, method: ServiceRequest.Method.post, headers: ["Content-Type":"application/json"], params: ["encrypted_message": message])

        let responseWithCode = try self.connection.send(requestForCode)

        guard let responseWithCodeBody = responseWithCode.body,
            let jsonWithCode = try JSONSerialization.jsonObject(with: responseWithCodeBody, options: []) as? [String: Any],
            let code = jsonWithCode["code"] as? String
            else {
                throw VirgilHelperError.gettingVirgilTokenFailed
        }

        let requestForVirgilToken = try ServiceRequest(url: URL(string: self.authServer + "v4/authorization/actions/obtain-access-token")!, method: ServiceRequest.Method.post, headers: ["Content-Type":"application/json"], params: ["grant_type": "access_code", "code": code])

        let responseWithVirgilToken = try self.connection.send(requestForVirgilToken)

        guard let responseWithVirgilTokenBody = responseWithVirgilToken.body,
            let jsonWithVirgilToken = try JSONSerialization.jsonObject(with: responseWithVirgilTokenBody, options: []) as? [String: Any],
            let accessToken = jsonWithVirgilToken["access_token"] as? String
            else {
                throw VirgilHelperError.gettingVirgilTokenFailed
        }

        return accessToken
    }
}
