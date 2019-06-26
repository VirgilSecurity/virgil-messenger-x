//
//  Virgil+Encryption.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/26/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import VirgilCrypto
import VirgilSDKRatchet
import VirgilCryptoRatchet

extension Virgil {
    func encryptGroup(_ text: String, channel: Channel) throws -> String {
        let session = try self.getGroupSession(of: channel) ?? self.startNewGroupSession(with: channel.cards)

        let ratchetMessage = try session.encrypt(string: text)
        try self.secureChat.storeGroupSession(session: session)

        return ratchetMessage.serialize().base64EncodedString()
    }

    func decryptGroup(_ encrypted: String, from identity: String, channel: Channel, sessionId: Data) throws -> String {
        guard let data = Data(base64Encoded: encrypted) else {
            throw Error.utf8ToDataFailed
        }

        guard let card = channel.cards.first(where: { $0.identity == identity }) else {
            throw CoreData.Error.invalidChannel
        }

        let ratchetMessage = try RatchetGroupMessage.deserialize(input: data)

        let session = try self.getGroupSession(of: channel) ?? self.startNewGroupSession(identity: identity, sessionId: sessionId)

        let decrypted = try session.decryptString(from: ratchetMessage, senderCardId: card.identifier)
        try self.secureChat.storeGroupSession(session: session)

        return decrypted
    }

    func encrypt(_ text: String, card: Card) throws -> String {
        let session = try self.getSessionAsSender(card: card)

        let ratchetMessage = try session.encrypt(string: text)
        try self.secureChat.storeSession(session: session)

        return ratchetMessage.serialize().base64EncodedString()
    }

    func decrypt(_ encrypted: String, from card: Card) throws -> String {
        guard let data = Data(base64Encoded: encrypted) else {
            throw Error.utf8ToDataFailed
        }

        let ratchetMessage = try RatchetMessage.deserialize(input: data)

        let session = try self.getSessionAsReceiver(message: ratchetMessage, receiverCard: card)

        let decrypted = try session.decryptString(from: ratchetMessage)
        try self.secureChat.storeSession(session: session)

        return decrypted
    }
}

// MARK: - Extension with session operations
extension Virgil {
    func getGroupSession(of channel: Channel) -> SecureGroupSession? {
        guard let sessionId = channel.sessionId,
            let session = self.secureChat.existingGroupSession(sessionId: sessionId) else {
                return nil
        }

        return session
    }

    private func getSessionAsSender(card: Card) throws -> SecureSession {
        guard let session = self.secureChat.existingSession(withParticpantIdentity: card.identity) else {
            return try secureChat.startNewSessionAsSender(receiverCard: card).startSync().getResult()
        }

        return session
    }

    private func getSessionAsReceiver(message: RatchetMessage, receiverCard card: Card) throws -> SecureSession {
        guard let session = self.secureChat.existingSession(withParticpantIdentity: card.identity) else {
            return try secureChat.startNewSessionAsReceiver(senderCard: card, ratchetMessage: message)
        }

        return session
    }

    func startNewGroupSession(with cards: [Card]) throws -> SecureGroupSession {
        let part = withUnsafeBytes(of: UUID().uuid, { Data($0) })
        let sessionId = part + part

        let newSessionMessage = try self.secureChat.startNewGroupSession(sessionId: sessionId)

        let members = cards.map { $0.identity }

        let serviceMessage = try ServiceMessage(identifier: nil,
                                                message: newSessionMessage,
                                                type: .newSession,
                                                members: members + [Twilio.shared.identity])

        try MessageSender.sendServiceMessage(to: members, ticket: serviceMessage).startSync().getResult()

        let session = try self.secureChat.startGroupSession(with: cards, using: newSessionMessage)
        try self.secureChat.storeGroupSession(session: session)

        return session
    }

    func startNewGroupSession(identity: String, sessionId: Data) throws -> SecureGroupSession {
        guard let serviceMessage = CoreData.shared.findServiceMessage(from: identity,
                                                                      withSessionId: sessionId) else {
            throw Error.missingServiceMessage
        }

        let members = serviceMessage.members.filter { $0 != Twilio.shared.identity }
        let cards = try CoreData.shared.getSingleChannelsCards(users: members)

        let session = try secureChat.startGroupSession(with: cards, using: serviceMessage.message)
        try self.secureChat.storeGroupSession(session: session)

        try CoreData.shared.delete(serviceMessage)

        return session
    }
}
