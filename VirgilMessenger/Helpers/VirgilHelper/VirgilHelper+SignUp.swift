//
//  VirgilHelper+SignUp.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/19/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation
import VirgilSDK
import VirgilCryptoApiImpl

extension VirgilHelper {
    /// Creates Key Pair, stores private key, publishes Virgil Card
    ///
    /// - Parameters:
    ///   - identity: identity of user
    ///   - completion: completion handler, called with error if failed
    func signUp(identity: String, completion: @escaping (Error?) -> ()) {
        self.setCardManager(identity: identity)
        guard let cardManager = self.cardManager else {
            Log.error("Missing CardManager")
            return
        }
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
                let keyPair = try self.crypto.generateKeyPair()
                self.set(privateKey: keyPair.privateKey)

                let rawCard = try cardManager.generateRawCard(privateKey: keyPair.privateKey,
                                                              publicKey: keyPair.publicKey,
                                                              identity: identity)

                let exportedRawCard = try rawCard.exportAsJson()

                let request = try ServiceRequest(url: URL(string: self.signUpEndpint)!,
                                                 method: ServiceRequest.Method.post,
                                                 headers: ["Content-Type": "application/json"],
                                                 params: ["rawCard" : exportedRawCard])

                let response = try self.connection.send(request)

                guard let responseBody = response.body,
                    let json = try JSONSerialization.jsonObject(with: responseBody, options: []) as? [String: Any] else {
                        Log.error("json failed")
                        throw VirgilHelperError.jsonParsingFailed
                }

                guard let exportedCard = json["virgil_card"] as? [String: Any] else {
                    Log.error("Error while signing up: server didn't return card")
                    DispatchQueue.main.async {
                        completion(UserFriendlyError.usernameAlreadyUsed)
                    }
                    return
                }
                let card = try cardManager.importCard(fromJson: exportedCard)

                let exportedPrivateKey = try VirgilPrivateKeyExporter().exportPrivateKey(privateKey: keyPair.privateKey)

                let keyEntry = KeyEntry(name: identity, value: exportedPrivateKey)
                try? self.keyStorage.deleteKeyEntry(withName: identity)
                try self.keyStorage.store(keyEntry)
                self.selfCard = card

                var resultError: Error? = nil
                let dispatchGroup = DispatchGroup()

                dispatchGroup.enter()
                let exportedPublishedCard = try cardManager.exportCardAsBase64EncodedString(card)
                CoreDataHelper.sharedInstance.createAccount(withIdentity: identity, exportedCard: exportedPublishedCard) {
                    dispatchGroup.leave()
                }

                dispatchGroup.enter()
                self.initializeAccount(withCardId: card.identifier, identity: identity) { error in
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
