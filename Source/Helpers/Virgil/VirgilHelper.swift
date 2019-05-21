//
//  VirgilHelper.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 11/4/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import VirgilCrypto
import VirgilSDKRatchet
import VirgilCryptoRatchet

public enum VirgilHelperError: String, Error {
    case getCardFailed = "Getting Virgil Card Failed"
    case cardVerifierInitFailed
    case utf8ToDataFailed
}

public class VirgilHelper {
    private(set) static var shared: VirgilHelper!

    let identity: String
    let crypto: VirgilCrypto
    let cardCrypto: VirgilCardCrypto
    let verifier: VirgilCardVerifier
    let client: Client
    let secureChat: SecureChat

    private init(crypto: VirgilCrypto,
                 cardCrypto: VirgilCardCrypto,
                 verifier: VirgilCardVerifier,
                 client: Client,
                 identity: String,
                 secureChat: SecureChat) {
        self.crypto = crypto
        self.cardCrypto = cardCrypto
        self.verifier = verifier
        self.client = client
        self.identity = identity
        self.secureChat = secureChat
    }

    public static func initialize(identity: String) throws {
        let crypto = try VirgilCrypto()
        let cardCrypto = VirgilCardCrypto(virgilCrypto: crypto)
        let client = Client(crypto: crypto, cardCrypto: cardCrypto)
        let localKeyManager = try LocalKeyManager(identity: identity, crypto: crypto)

        guard let verifier = VirgilCardVerifier(cardCrypto: cardCrypto) else {
            throw VirgilHelperError.cardVerifierInitFailed
        }

        guard let user = localKeyManager.retrieveUserData() else {
            throw NSError()
        }

        let provider = client.makeAccessTokenProvider(identity: identity)

        let context = SecureChatContext(identity: identity,
                                        identityCard: user.card,
                                        identityKeyPair: user.keyPair,
                                        accessTokenProvider: provider)

        let secureChat = try SecureChat(context: context)

        self.shared = VirgilHelper(crypto: crypto,
                                   cardCrypto: cardCrypto,
                                   verifier: verifier,
                                   client: client,
                                   identity: identity,
                                   secureChat: secureChat)
    }

    public func makeInitPFSOperation(identity: String) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let rotationLog = try self.secureChat.rotateKeys().startSync().getResult()
                Log.debug(rotationLog.description)

                completion((), nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    func makeGetCardsOperation(identities: [String]) -> CallbackOperation<[Card]> {
        return CallbackOperation { _, completion in
            do {
                let cards = try self.client.searchCards(identities: identities,
                                                        selfIdentity: self.identity,
                                                        verifier: self.verifier)

                guard !cards.isEmpty else {
                    throw UserFriendlyError.userNotFound
                }

                completion(cards, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    func makeSendServiceMessageOperation(cards: [Card], ticket: String) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            guard !cards.isEmpty else {
                completion((), nil)
                return
            }

            var operations: [CallbackOperation<Void>] = []
            for card in cards {
                guard let channel = CoreDataHelper.shared.getSingleChannel(with: card.identity) else {
                    continue
                }

                let sendOperation = MessageSender.makeSendServiceMessageOperation(ticket, to: channel)
                operations.append(sendOperation)
            }

            let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

            operations.forEach {
                completionOperation.addDependency($0)
            }

            let queue = OperationQueue()
            queue.addOperations(operations + [completionOperation], waitUntilFinished: false)
        }
    }

    func makeSendChangeMembersServiceMessageOperation(add: [Card], remove: [Card], channel: Channel) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                guard let session = self.getGroupSession(of: channel) else {
                    completion((), nil)
                    return
                }

                let removeCardIds = remove.map { $0.identifier }
                let message = try session.createChangeMembersTicket(add: add, removeCardIds: removeCardIds)

                let userTicketOperation = CallbackOperation<Void> { _, completion in
                    do {
                        try session.useChangeMembersTicket(ticket: message, addCards: add, removeCardIds: removeCardIds)
                        completion((), nil)
                    } catch {
                        completion(nil, error)
                    }
                }

                let serviceMessage = try ServiceMessage(message: message,
                                                        type: .changeMembers,
                                                        members: channel.cards,
                                                        add: add,
                                                        remove: remove)

                let serialized = try serviceMessage.export()

                let sendServiceChangeMembersOperation = MessageSender.makeSendServiceMessageOperation(serialized, to: channel)
                let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

                userTicketOperation.addDependency(sendServiceChangeMembersOperation)
                completionOperation.addDependency(sendServiceChangeMembersOperation)
                completionOperation.addDependency(userTicketOperation)

                let queue = OperationQueue()
                queue.addOperations([sendServiceChangeMembersOperation, userTicketOperation, completionOperation], waitUntilFinished: false)
            } catch {
                completion(nil, error)
            }
        }
    }

    func buildCard(_ card: String) -> Card? {
        do {
            let card = try self.importCard(fromBase64Encoded: card)

            return card
        } catch {
            Log.error("Importing Card failed with: \(error.localizedDescription)")

            return nil
        }
    }

    func importCard(fromBase64Encoded card: String) throws -> Card {
        return try CardManager.importCard(fromBase64Encoded: card,
                                          cardCrypto: self.cardCrypto,
                                          cardVerifier: self.verifier)
    }
}
