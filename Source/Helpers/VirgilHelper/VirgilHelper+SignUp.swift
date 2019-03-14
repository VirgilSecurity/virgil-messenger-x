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
                let cardManager = try self.setCardManager(identity: identity)

                if self.keyStorage.existsKeyEntry(withName: identity) {
                    throw UserFriendlyError.usernameAlreadyUsed
                }

                let keyPair = try self.crypto.generateKeyPair()
                self.set(privateKey: keyPair.privateKey)

                let rawCard = try cardManager.generateRawCard(privateKey: keyPair.privateKey,
                                                              publicKey: keyPair.publicKey,
                                                              identity: identity)
                let card = try self.requestSignUp(rawCard: rawCard, cardManager: cardManager)
                self.set(selfCard: card)

                let exportedCard = try cardManager.exportCardAsBase64EncodedString(card)
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

    /// Publishes card with given identity using backend
    ///
    /// - Parameters:
    ///   - identity: identity of user
    ///   - cardManager: Card Manager instance
    /// - Returns: Card
    /// - Throws: corresponding error if fails
    private func requestSignUp(rawCard: RawSignedModel, cardManager: CardManager) throws -> Card {
        let exportedRawCard = try rawCard.exportAsJson()

        let connection = HttpConnection()
        let requestURL = URLConstansts.signUpEndpoint
        let headers = ["Content-Type": "application/json"]
        let params = ["rawCard" : exportedRawCard]
        let body = try JSONSerialization.data(withJSONObject: params, options: [])

        let request = Request(url: requestURL, method: .post, headers: headers, body: body)
        let response = try connection.send(request)

        if let body = response.body,
            let text = String(data: body, encoding: .utf8),
            text == "Card with this identity already exists" {
                throw UserFriendlyError.usernameAlreadyUsed
        }

        guard let responseBody = response.body,
            let json = try JSONSerialization.jsonObject(with: responseBody, options: []) as? [String: Any] else {
                Log.error("Json parsing failed")
                throw VirgilHelperError.jsonParsingFailed
        }

        guard let exportedCard = json["virgil_card"] as? [String: Any] else {
            Log.error("Error while signing up: server didn't return card")
            throw UserFriendlyError.usernameAlreadyUsed
        }

        return try cardManager.importCard(fromJson: exportedCard)
    }
}
