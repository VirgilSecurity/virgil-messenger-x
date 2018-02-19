//
//  VirgilHelper+SignIn.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/19/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation
import VirgilSDKPFS

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

        if let exportedCard = exportedCard, let card = VSSCard(data: exportedCard) {
            self.signInHelper(card: card, identity: identity) { error in
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        } else {
            getCard(withIdentity: identity) { card, error in
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

    private func signInHelper(card: VSSCard, identity: String, completion: @escaping (Error?) -> ()) {
        guard let publicKey = self.crypto.importPublicKey(from: card.publicKeyData) else {
            DispatchQueue.main.async {
                completion(VirgilHelperError.importingKeyFailed)
            }
            return
        }
        self.setPublicKey(publicKey)

        var resultError: Error? = nil
        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        self.initializeAccount(withCardId: card.identifier, identity: identity) { error in
            resultError = error
            dispatchGroup.leave()
        }
        do {
            let entry = try self.keyStorage.loadKeyEntry(withName: identity)
            guard let key = self.crypto.importPrivateKey(from: entry.value) else {
                throw VirgilHelperError.importingKeyFailed
            }
           self.setPrivateKey(key)

            dispatchGroup.enter()
            self.initializePFS(withIdentity: identity, card: card, privateKey: key) { error in
                //FIXME
                //resultError = error
                dispatchGroup.leave()
            }
        } catch {
            resultError = error
        }

        dispatchGroup.notify(queue: .main) {
            if let error = resultError {
                Log.error("Signing in: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                completion(resultError)
            }
        }
    }
}
