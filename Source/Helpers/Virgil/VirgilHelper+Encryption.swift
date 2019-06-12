//
//  VirgilHelper+Encryption.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/26/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import VirgilCrypto
import VirgilSDKRatchet
import VirgilCryptoRatchet

extension VirgilHelper {
    func encryptGroup(_ text: String, channel: Channel) throws -> String {
        let session = try self.getGroupSession(of: channel) ?? self.startNewGroupSession(with: channel.cards)

        let ratchetMessage = try session.encrypt(string: text)

        return ratchetMessage.serialize().base64EncodedString()
    }

    func decryptGroup(_ encrypted: String, from identity: String, channel: Channel, sessionId: Data) throws -> String {
        guard let data = Data(base64Encoded: encrypted) else {
            throw VirgilHelperError.utf8ToDataFailed
        }

        let ratchetMessage = try RatchetGroupMessage.deserialize(input: data)

        let session = try self.getGroupSession(of: channel) ?? self.startNewGroupSession(identity: identity, sessionId: sessionId)

        return try session.decryptString(from: ratchetMessage)
    }

    func encrypt(_ text: String, card: Card) throws -> String {
        let session = try self.getSessionAsSender(card: card)

        let ratchetMessage = try session.encrypt(string: text)

        return ratchetMessage.serialize().base64EncodedString()
    }

    func decrypt(_ encrypted: String, from card: Card) throws -> String {
        guard let data = Data(base64Encoded: encrypted) else {
            throw VirgilHelperError.utf8ToDataFailed
        }

        let ratchetMessage = try RatchetMessage.deserialize(input: data)

        let session = try self.getSessionAsReceiver(message: ratchetMessage, receiverCard: card)

        return try session.decryptString(from: ratchetMessage)
    }
}

// MARK: - Extension with session operations
extension VirgilHelper {
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
        let newSessionMessage = try self.secureChat.startNewGroupSession()

        let serviceMessage = try ServiceMessage(identifier: nil,
                                                message: newSessionMessage,
                                                type: .newSession,
                                                members: cards)

        try MessageSender.sendServiceMessage(to: cards, ticket: serviceMessage).startSync().getResult()

        let cards = cards.filter { $0.identity != TwilioHelper.shared.username }
        let session = try secureChat.startGroupSession(with: cards, using: newSessionMessage)
        try session.sessionStorage.storeSession(session)

        return session
    }

    func startNewGroupSession(identity: String, sessionId: Data) throws -> SecureGroupSession {
        guard let serviceMessage = try CoreDataHelper.shared.findServiceMessage(from: identity,
                                                                                withSessionId: sessionId) else {
            throw VirgilHelperError.missingServiceMessage
        }

        let session = try secureChat.startGroupSession(with: serviceMessage.cards, using: serviceMessage.message)
        try session.sessionStorage.storeSession(session)

        try CoreDataHelper.shared.delete(serviceMessage)

        return session
    }
}
