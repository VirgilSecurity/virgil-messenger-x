//
//  VirgilHelper+SignUp.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/19/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation
import VirgilSDK
import VirgilCrypto

extension VirgilHelper {
    func signUp(identity: String) -> GenericOperation<String> {
        return CallbackOperation { _, completion in
            do {
                if self.keyStorage.existsKeyEntry(withName: identity) {
                    throw UserFriendlyError.usernameAlreadyUsed
                }

                let keyPair = try self.crypto.generateKeyPair()

                let modelSigner = ModelSigner(cardCrypto: self.cardCrypto)
                let rawCard = try CardManager.generateRawCard(cardCrypto: self.cardCrypto,
                                                              modelSigner: modelSigner,
                                                              privateKey: keyPair.privateKey,
                                                              publicKey: keyPair.publicKey,
                                                              identity: identity)
                let card = try self.client.signUp(rawCard: rawCard,
                                                  cardCrypto: self.cardCrypto,
                                                  verifier: self.verifier)
                self.set(privateKey: keyPair.privateKey)
                self.set(selfCard: card)

                let exportedCard = try self.export(card: card)
                let exportedPrivateKey = try VirgilPrivateKeyExporter(virgilCrypto: self.crypto).exportPrivateKey(privateKey: keyPair.privateKey)

                let keyEntry = KeyEntry(name: identity, value: exportedPrivateKey)
                try? self.keyStorage.deleteKeyEntry(withName: identity)
                try self.keyStorage.store(keyEntry)

                let initPFSOperation = self.makeInitPFSOperation(identity: identity,
                                                                 cardId: card.identifier,
                                                                 privateKey: keyPair.privateKey)
                let initTwilioOperation = self.makeInitTwilioOperation(cardId: card.identifier, identity: identity)

                let operations = [initPFSOperation, initTwilioOperation]
                let completionOperation = OperationUtils.makeCompletionOperation(completion: { (_: Void?, error: Error?) in
                    completion(exportedCard, error)
                })

                operations.forEach {
                    completionOperation.addDependency($0)
                }

                let queue = OperationQueue()
                queue.addOperations(operations + [completionOperation], waitUntilFinished: true)
            } catch {
                completion(nil, error)
            }
        }
    }
}
