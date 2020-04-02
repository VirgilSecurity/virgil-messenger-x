//
//  Virgil+CryptoOperation.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 02.04.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

extension Virgil {
    public static func encrypt(data: Data, for channel: Storage.Channel) throws -> Data {
        let card = try channel.getCard()

        if channel.type == .singleRatchet, let ratchetChannel = try Virgil.ethree.getRatchetChannel(with: card) {
            return try ratchetChannel.encrypt(data: data)
        } else {
            return try Virgil.ethree.authEncrypt(data: data, for: card)
        }
    }

    public static func decrypt(_ message: EncryptedMessage, from channel: Storage.Channel) throws -> Data {
        let decrypted: Data

        do {
            decrypted = try self.decrypt(message.ciphertext, from: channel)
        } catch {
            // TODO: check if needed
            try Storage.shared.createEncryptedMessage(in: channel, isIncoming: true, date: message.date)

            throw error
        }

        return decrypted
    }

    public static func decrypt(_ data: Data, from channel: Storage.Channel) throws -> Data {
        if channel.type == .singleRatchet {
            guard let ratchetChannel = try Virgil.ethree.getRatchetChannel(with: channel.getCard()) else {
                throw UserFriendlyError.noUserOnDevice
            }

            do {
                return try ratchetChannel.decrypt(data: data)
            } catch {
                return try Virgil.ethree.authDecrypt(data: data, from: channel.getCard())
            }
        } else {
            return try Virgil.ethree.authDecrypt(data: data, from: channel.getCard())
        }
    }
}
