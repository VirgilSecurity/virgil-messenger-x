//
//  VirgilHelper+SignIn.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/19/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation
import VirgilSDK

extension VirgilHelper {
    /// Loads private key, initializes Twilio
    ///
    /// - Parameters:
    ///   - identity: identity of user
    ///   - completion: completion handler, called with error if failed
    func signIn(identity: String, card exportedCard: String?, completion: @escaping (Error?) -> ()) {
        self.queue.async {
            Log.debug("Signing in")

            self.setCardManager(identity: identity)
            do {
                guard let cardManager = self.cardManager else {
                    throw VirgilHelperError.missingCardManager
                }

                if !self.keyStorage.existsKeyEntry(withName: identity) {
                    Log.error("Key not found")
                    throw UserFriendlyError.noUserOnDevice
                }

                if let exportedCard = exportedCard {
                    let card = try cardManager.importCard(fromBase64Encoded: exportedCard)
                    self.signInHelper(card: card, identity: identity) { error in
                        DispatchQueue.main.async {
                            completion(error)
                        }
                    }
                } else {
                    let card = try self.requestSignIn(identity: identity, cardManager: cardManager)
                    self.signInHelper(card: card, identity: identity) { error in
                        DispatchQueue.main.async {
                            completion(error)
                        }
                    }
                }
            } catch {
                Log.error("Signing in: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }

    private func signInHelper(card: Card, identity: String, completion: @escaping (Error?) -> ()) {
        self.set(selfCard: card)
        do {
            let entry = try self.keyStorage.loadKeyEntry(withName: identity)
            let key = try self.crypto.importPrivateKey(from: entry.value)
            self.set(privateKey: key)
            self.setCardManager(identity: identity)
        } catch {
            Log.error("\(error.localizedDescription)")
            completion(error)
        }

        self.initializeTwilio(cardId: card.identifier, identity: identity) { error in
            if let error = error {
                Log.error("Signing in: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }

    /// Returns card with given identity using backend
    ///
    /// - Parameters:
    ///   - identity: identity of user
    ///   - cardManager: Card Manager instance
    /// - Returns: Card
    /// - Throws: corresponding error if fails
    private func requestSignIn(identity: String, cardManager: CardManager) throws -> Card {
        let request = try ServiceRequest(url: URL(string: self.signUpEndpint)!,
                                         method: ServiceRequest.Method.post,
                                         headers: ["Content-Type": "application/json"],
                                         params: ["identity" : identity])
        let response = try self.connection.send(request)

        guard let responseBody = response.body,
            let json = try JSONSerialization.jsonObject(with: responseBody, options: []) as? [String: Any] else {
                Log.error("Json parsing failed")
                throw VirgilHelperError.jsonParsingFailed
        }

        guard let exportedCard = json["virgil_card"] as? [String: Any] else {
            Log.error("Error while signing up: server didn't return card")
            throw VirgilHelperError.jsonParsingFailed
        }

        return try cardManager.importCard(fromJson: exportedCard)
    }
}
