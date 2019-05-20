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
        let session = try self.getGroupSessionAsSender(channel: channel)

        let ratchetMessage = try session.encrypt(string: text)

        return ratchetMessage.serialize().base64EncodedString()
    }

    func decryptGroup(_ encrypted: String, from identity: String, channel: Channel, sessionId: Data) throws -> String {
        guard let data = Data(base64Encoded: encrypted) else {
            throw VirgilHelperError.utf8ToDataFailed
        }

        let ratchetMessage = try RatchetGroupMessage.deserialize(input: data)

        CoreDataHelper.shared.setSessionId(sessionId, for: channel)

        let session = try self.getGroupSessionAsReceiver(identity: identity, sessionId: sessionId)

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
        guard let session = secureChat.existingSession(withParticpantIdentity: card.identity) else {
            return try secureChat.startNewSessionAsSender(receiverCard: card).startSync().getResult()
        }

        return session
    }

    private func getSessionAsReceiver(message: RatchetMessage, receiverCard card: Card) throws -> SecureSession {
        guard let session = secureChat.existingSession(withParticpantIdentity: card.identity) else {
            return try secureChat.startNewSessionAsReceiver(senderCard: card, ratchetMessage: message)
        }

        return session
    }

    private func getGroupSessionAsSender(channel: Channel) throws -> SecureGroupSession {
        guard let session = self.getGroupSession(of: channel) else {
            let newSessionMessage = try self.secureChat.startNewGroupSession(with: channel.cards)
            let sessionId = newSessionMessage.getSessionId()

            let serviceMessage = try ServiceMessage(message: newSessionMessage, type: .newSession, members: channel.cards)
            let serialized = try serviceMessage.export()

            try VirgilHelper.shared.makeSendServiceMessageOperation(cards: channel.cards,
                                                                    ticket: serialized).startSync().getResult()

            CoreDataHelper.shared.setSessionId(sessionId, for: channel)

            return try secureChat.startGroupSession(with: channel.cards, using: newSessionMessage)
        }

        return session
    }

    private func getGroupSessionAsReceiver(identity: String, sessionId: Data) throws -> SecureGroupSession {
        guard let session = secureChat.existingGroupSession(sessionId: sessionId) else {

            let serviceMessage = try CoreDataHelper.shared.findServiceMessage(from: identity,
                                                                              type: .newSession,
                                                                              withSessionId: sessionId)

            let session = try secureChat.startGroupSession(with: serviceMessage.cards, using: serviceMessage.message)

            CoreDataHelper.shared.delete(serviceMessage: serviceMessage)

            return session
        }

        return session
    }
}
