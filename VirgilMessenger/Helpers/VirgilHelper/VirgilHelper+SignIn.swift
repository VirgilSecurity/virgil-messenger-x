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
        self.setCardManager(identity: identity)
        
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

        if let exportedCard = exportedCard,
            let cardManager = self.cardManager,
            let card = try? cardManager.importCard(fromBase64Encoded: exportedCard) {
                self.selfCard = card
                self.signInHelper(card: card, identity: identity) { error in
                    DispatchQueue.main.async {
                        completion(error)
                    }
                }
        } else {
           completion(VirgilHelperError.missingCardLocally)
        }
    }

    private func signInHelper(card: Card, identity: String, completion: @escaping (Error?) -> ()) {
        do {
            let entry = try self.keyStorage.loadKeyEntry(withName: identity)
            let key = try self.crypto.importPrivateKey(from: entry.value)
            self.set(privateKey: key)
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
