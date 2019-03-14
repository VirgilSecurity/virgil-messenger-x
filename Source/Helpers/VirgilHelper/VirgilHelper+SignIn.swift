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
    func signIn(identity: String, card exportedCard: String) -> GenericOperation<Void> {
        return CallbackOperation { _, completion in
            self.queue.async {
                do {
                    if !self.keyStorage.existsKeyEntry(withName: identity) {
                        throw UserFriendlyError.noUserOnDevice
                    }

                    let card = try self.importCard(fromBase64Encoded: exportedCard)
                    self.set(selfCard: card)

                    let entry = try self.keyStorage.loadKeyEntry(withName: identity)
                    let keyPair = try self.crypto.importPrivateKey(from: entry.value)
                    self.set(privateKey: keyPair.privateKey)

                    let initPFSOperation = self.makeInitPFSOperation(identity: identity,
                                                                     cardId: card.identifier,
                                                                     privateKey: keyPair.privateKey)
                    let initTwilioOperation = self.makeInitTwilioOperation(cardId: card.identifier, identity: identity)

                    let operations = [initPFSOperation, initTwilioOperation]
                    let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)
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
}
