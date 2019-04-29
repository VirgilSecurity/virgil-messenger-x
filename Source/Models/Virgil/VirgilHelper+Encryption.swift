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

    private func getGroupSession(sessionId: String) throws -> SecureGroupSession {
        guard let session = secureChat.existingGroupSession(sessionId: sessionId) else {
            throw NSError()
        }

        return session
    }

    public func getStartGroupTicket(_ cards: [Card]) throws -> RatchetGroupMessage {
        return try self.secureChat.startNewGroupSession(with: cards)
    }

    func encrypt(_ text: String, groupSessionId: String) throws -> String {
        let session = try self.getGroupSession(sessionId: groupSessionId)

        let ratchetMessage = try session.encrypt(string: text)

        return ratchetMessage.serialize().base64EncodedString()
    }

    func encrypt(_ text: String, card: Card) throws -> String {
        let session = try self.getSessionAsSender(card: card)

        let ratchetMessage = try session.encrypt(string: text)

        return ratchetMessage.serialize().base64EncodedString()
    }

    func decrypt(_ encrypted: String, from card: Card) throws -> String {
        guard let data = Data(base64Encoded: encrypted) else {
            Log.error("Converting utf8 string to data failed")
            throw NSError()
        }

        let ratchetMessage = try RatchetMessage.deserialize(input: data)

        let session = try self.getSessionAsReceiver(message: ratchetMessage, receiverCard: card)

        return try session.decryptString(from: ratchetMessage)
    }
}
