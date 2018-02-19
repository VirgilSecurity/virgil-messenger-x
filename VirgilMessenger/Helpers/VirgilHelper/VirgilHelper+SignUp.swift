//
//  VirgilHelper+SignUp.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/19/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation
import VirgilSDKPFS

extension VirgilHelper {
    func signUp(identity: String, identityType: String = "name", completion: @escaping (Error?) -> ()) {
        self.queue.async {
            Log.debug("Signing up")

            if self.keyStorage.existsKeyEntry(withName: identity) {
                Log.debug("Key already stored for this identity")
                DispatchQueue.main.async {
                    completion(UserFriendlyError.usernameAlreadyUsed)
                }
                return
            }
            do {
                let keyPair = self.crypto.generateKeyPair()
                self.setPrivateKey(keyPair.privateKey)
                self.setPublicKey(keyPair.publicKey)

                let exportedPublicKey = self.crypto.export(keyPair.publicKey)
                let csr = VSSCreateUserCardRequest(identity: identity, identityType: identityType, publicKeyData: exportedPublicKey, data: ["deviceId": "testDevice123"])

                let signer = VSSRequestSigner(crypto: self.crypto)
                try signer.selfSign(csr, with: keyPair.privateKey)

                let exportedCSR = csr.exportData()
                let request = try ServiceRequest(url: URL(string: self.twilioServer + "v1/users")!, method: ServiceRequest.Method.post, headers: ["Content-Type":"application/json"], params: ["csr" : exportedCSR])

                let response = try self.connection.send(request)

                guard let responseBody = response.body,
                    let json = try JSONSerialization.jsonObject(with: responseBody, options: []) as? [String: Any]
                    else {
                        Log.error("json failed")
                        throw VirgilHelperError.jsonParsingFailed
                }

                guard let exportedCard = json["virgil_card"] as? String else {
                    Log.error("Error while signing up: server didn't return card")
                    DispatchQueue.main.async {
                        completion(UserFriendlyError.usernameAlreadyUsed)
                    }
                    return
                }
                guard let card = VSSCard(data: exportedCard) else {
                    Log.error("Can't build card")
                    throw VirgilHelperError.buildCardFailed
                }

                guard self.validator.validate(card.cardResponse) else {
                    Log.error("validating card failed")
                    throw VirgilHelperError.validatingError
                }

                let keyEntry = VSSKeyEntry(name: identity, value: self.crypto.export(keyPair.privateKey, withPassword: nil))
                try? self.keyStorage.deleteKeyEntry(withName: identity)
                try self.keyStorage.store(keyEntry)

                var resultError: Error? = nil
                let dispatchGroup = DispatchGroup()

                dispatchGroup.enter()
                CoreDataHelper.sharedInstance.createAccount(withIdentity: identity, exportedCard: card.exportData()) {
                    dispatchGroup.leave()
                }

                dispatchGroup.enter()
                self.initializeAccount(withCardId: card.identifier, identity: identity) { error in
                    resultError = error
                    dispatchGroup.leave()
                }
                dispatchGroup.enter()
                self.initializePFS(withIdentity: identity, card: card, privateKey: keyPair.privateKey) { error in
                    resultError = error
                    dispatchGroup.leave()
                }

                dispatchGroup.notify(queue: .main) {
                    if let error = resultError {
                        Log.error("Signing up: \(error.localizedDescription)")
                    }
                    DispatchQueue.main.async {
                        completion(resultError)
                    }
                }
            } catch {
                Log.error("Signing up: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }
}
