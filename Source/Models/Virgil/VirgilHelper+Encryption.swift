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
    private func getSessionAsSender() throws -> SecureSession {
        guard let card = self.channelCard else {
            Log.error("channel card not found")
            throw NSError()
        }

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

    func encryptPFS(_ text: String) throws -> String {
        let session = try self.getSessionAsSender()

        let ratchetMessage = try session.encrypt(string: text)

        return ratchetMessage.serialize().base64EncodedString()
    }

    func decryptPFS(_ encrypted: String) throws -> String {
        guard let data = Data(base64Encoded: encrypted) else {
            Log.error("Converting utf8 string to data failed")
            throw NSError()
        }

        guard let card = self.channelCard else {
            Log.error("channel card not found")
            throw NSError()
        }

        let ratchetMessage = try RatchetMessage.deserialize(input: data)

        let session = try self.getSessionAsReceiver(message: ratchetMessage, receiverCard: card)

        return try session.decryptString(from: ratchetMessage)
    }

    func encrypt(_ text: String) -> String? {
        let session = try! self.getSessionAsSender()

        let ratchetMessage = try! session.encrypt(string: text)

        return ratchetMessage.serialize().base64EncodedString()
    }

    func decrypt(_ encrypted: String, withCard: String? = nil) -> String? {
        guard let data = Data(base64Encoded: encrypted) else {
            Log.error("Converting utf8 string to data failed")
            return nil
        }

        let tryCard: Card?
        if let receiverCard = withCard {
            tryCard = self.buildCard(receiverCard)
        } else {
            tryCard = self.channelCard
        }

        guard let card = tryCard else {
            Log.error("No card")
            return nil
        }

        do {
            let ratchetMessage = try RatchetMessage.deserialize(input: data)

            let session = try self.getSessionAsReceiver(message: ratchetMessage, receiverCard: card)

            return try session.decryptString(from: ratchetMessage)
        } catch {
            Log.error("\(error.localizedDescription)")
            return nil
        }
    }
}
