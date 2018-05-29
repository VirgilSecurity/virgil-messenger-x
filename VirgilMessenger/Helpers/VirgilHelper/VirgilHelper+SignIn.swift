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
    func signIn(identity: String, completion: @escaping (Error?) -> ()) {
        Log.debug("Signing in")

        if !keyStorage.existsKeyEntry(withName: identity) {
            DispatchQueue.main.async {
                completion(UserFriendlyError.noUserOnDevice)
            }
            Log.error("Key not found")
            return
        }

        guard CoreDataHelper.sharedInstance.loadAccount(withIdentity: identity) else {
            DispatchQueue.main.async {
                completion(UserFriendlyError.noUserOnDevice)
            }
            return
        }

        let exportedCard = CoreDataHelper.sharedInstance.getAccountCard()

        if let exportedCard = exportedCard, let card = self.importCard(exportedCard) {
            self.card = card
            self.signInHelper(card: card, identity: identity) { error in
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        } else {
            getCard(identity: identity) { card, error in
                self.card = card
                guard error == nil, let card = card else {
                    Log.error("Signing in: can't get virgil card: \(error?.localizedDescription ?? "")")
                    DispatchQueue.main.async {
                        completion(error)
                    }
                    return
                }

                self.signInHelper(card: card, identity: identity) { error in
                    DispatchQueue.main.async {
                        completion(error)
                    }
                }
            }
        }
    }

    private func importCard(_ string: String) -> Card? {
        do {
            let rawCard = try RawSignedModel.import(fromBase64Encoded: string)
            let card = try CardManager.parseCard(from: rawCard, cardCrypto: self.cardCrypto)
            guard self.verifier.verifyCard(card) else {
                return nil
            }

            return card
        } catch {
            return nil
        }
    }

    private func signInHelper(card: Card, identity: String, completion: @escaping (Error?) -> ()) {
        do {
            let entry = try self.keyStorage.loadKeyEntry(withName: identity)
            let key = try self.crypto.importPrivateKey(from: entry.value)
            self.set(privateKey: key)
            self.update(identity: identity)
        } catch {
            Log.error("\(error.localizedDescription)")
            completion(error)
        }

        self.initializeAccount(withCardId: card.identifier, identity: identity) { error in
            if let error = error {
                Log.error("Signing in: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(error)
                }
            }
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }
}
