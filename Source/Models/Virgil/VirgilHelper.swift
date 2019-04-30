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

    func makeSendNewMessageServiceMessageOperation(cards: [Card], newSessionTicket: Data) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            var operations: [CallbackOperation<Void>] = []
            cards.forEach {
                let sendOperation = MessageSender.makeSendServiceMessageOperation(newSessionTicket, to: $0)
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
