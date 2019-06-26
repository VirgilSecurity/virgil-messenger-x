//
//  Virgil.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 11/4/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import VirgilCrypto
import VirgilSDKRatchet
import VirgilCryptoRatchet

public class Virgil {
    private(set) static var shared: Virgil!

    public enum Error: String, Swift.Error {
        case cardVerifierInitFailed
        case utf8ToDataFailed
        case missingServiceMessage
        case nilGroupSession
    }

    let identity: String
    let crypto: VirgilCrypto
    let cardCrypto: VirgilCardCrypto
    let verifier: VirgilCardVerifier
    let client: Client
    let secureChat: SecureChat
    let localKeyManager: LocalKeyManager

    private init(crypto: VirgilCrypto,
                 cardCrypto: VirgilCardCrypto,
                 verifier: VirgilCardVerifier,
                 client: Client,
                 identity: String,
                 secureChat: SecureChat,
                 localKeyManager: LocalKeyManager) {
        self.crypto = crypto
        self.cardCrypto = cardCrypto
        self.verifier = verifier
        self.client = client
        self.identity = identity
        self.secureChat = secureChat
        self.localKeyManager = localKeyManager
    }

    public static func initialize(identity: String) throws {
        let crypto = try VirgilCrypto()
        let cardCrypto = VirgilCardCrypto(virgilCrypto: crypto)
        let client = Client(crypto: crypto, cardCrypto: cardCrypto)
        let localKeyManager = try LocalKeyManager(identity: identity, crypto: crypto)

        guard let verifier = VirgilCardVerifier(cardCrypto: cardCrypto) else {
            throw Error.cardVerifierInitFailed
        }

        let user = try localKeyManager.retrieveUserData()

        let provider = client.makeAccessTokenProvider(identity: identity)

        let context = SecureChatContext(identityCard: user.card,
                                        identityKeyPair: user.keyPair,
                                        accessTokenProvider: provider)

        let secureChat = try SecureChat(context: context)

        self.shared = Virgil(crypto: crypto,
                                   cardCrypto: cardCrypto,
                                   verifier: verifier,
                                   client: client,
                                   identity: identity,
                                   secureChat: secureChat,
                                   localKeyManager: localKeyManager)
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

    func createChangeMemebersTicket(in channel: Channel) throws -> RatchetGroupMessage {
        guard let session = self.getGroupSession(of: channel) else {
            throw Error.nilGroupSession
        }

        return try session.createChangeParticipantsTicket()
    }

    func updateParticipants(ticket: RatchetGroupMessage,
                            channel: Channel,
                            add: [Card] = [],
                            remove: [Card] = []) throws {
        guard let session = self.getGroupSession(of: channel) else {
            throw Error.nilGroupSession
        }

        let removeIds = remove.map { $0.identifier }

        try session.updateParticipants(ticket: ticket, addCards: add, removeCardIds: removeIds)

        try self.secureChat.storeGroupSession(session: session)
    }

    func updateParticipants(add: [Card], remove: [Card], members: [Card], serviceMessage: ServiceMessage, channel: Channel) throws {
        let members = members.filter { $0.identity != Twilio.shared.identity }

        let removeCardIds = remove.map { $0.identifier }

        let session: SecureGroupSession
        if let existing = self.getGroupSession(of: channel) {
            do {
                try existing.updateParticipants(ticket: serviceMessage.message,
                                                addCards: add,
                                                removeCardIds: removeCardIds)
                session = existing
            } catch {
                session = try self.secureChat.startGroupSession(with: members,
                                                                using: serviceMessage.message)
            }
        } else {
            session = try self.secureChat.startGroupSession(with: members,
                                                            using: serviceMessage.message)
        }

        try self.secureChat.storeGroupSession(session: session)
    }

    // FIXME: Should be in separate class
    func getCards(of users: [String]) throws -> [Card] {
        var cachedCards: [Card] = []
        var cardsToLoad: [String] = []

        let users = users.filter { $0 != Twilio.shared.identity }

        guard !users.isEmpty else {
            return []
        }

        for user in users {
            if let cachedCard = try CoreData.shared.getSingleChannel(with: user)?.getCard() {
                cachedCards.append(cachedCard)
            } else {
                cardsToLoad.append(user)
            }
        }

        guard !cardsToLoad.isEmpty else {
            return cachedCards
        }

        let cards = try self.makeGetCardsOperation(identities: cardsToLoad).startSync().getResult()

        try? ChatsManager.startSingle(cards: cards)

        return cachedCards + cards
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

    func makeHash(from string: String) -> String? {
        guard let data = string.data(using: .utf8) else {
            return nil
        }

        return self.crypto.computeHash(for: data, using: .sha256).hexEncodedString()
    }
}
