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
                let keyPair = try self.crypto.generateKeyPair()
                self.set(privateKey: keyPair.privateKey)

                let exportedPublicKey = self.crypto.exportPublicKey(keyPair.publicKey)

                let cardContent = RawCardContent(identity: identity, publicKey: exportedPublicKey,
                                                 previousCardId: nil, createdAt: Date())

                let snapshot = try JSONEncoder().encode(cardContent)

                let rawCard = RawSignedModel(contentSnapshot: snapshot)

                let modelSigner = ModelSigner(cardCrypto: self.cardCrypto)
                try modelSigner.selfSign(model: rawCard, privateKey: keyPair.privateKey)

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
                let publishedRawCard = try RawSignedModel.import(fromJson: exportedCard)
                let card = try CardManager.parseCard(from: publishedRawCard, cardCrypto: self.cardCrypto)
                guard self.verifier.verifyCard(card) else {
                    Log.error("Card is not valid")
                    throw VirgilHelperError.cardWasNotVerified
                }

                let exportedPrivateKey = try VirgilPrivateKeyExporter().exportPrivateKey(privateKey: keyPair.privateKey)

                let keyEntry = KeyEntry(name: identity, value: exportedPrivateKey)
                try? self.keyStorage.deleteKeyEntry(withName: identity)
                try self.keyStorage.store(keyEntry)

                self.card = card

                var resultError: Error? = nil
                let dispatchGroup = DispatchGroup()

                dispatchGroup.enter()
                let exportedPublichedCard = try card.getRawCard().exportAsBase64EncodedString()
                CoreDataHelper.sharedInstance.createAccount(withIdentity: identity, exportedCard: exportedPublichedCard) {
                    dispatchGroup.leave()
                }

                dispatchGroup.enter()
                self.update(identity: identity)
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
