//
//  MessageProcessor.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/3/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import Foundation

class MessageProcessor {
    static func process(_ encryptedMessage: EncryptedMessage, from author: String) throws {
        let channel = try self.setupCoreChannel(name: author)

        let decrypted = try self.decrypt(encryptedMessage, from: channel)

        let messageContent = try self.migrationSafeContentImport(from: decrypted,
                                                                 version: encryptedMessage.version)

        try self.process(messageContent, channel: channel, date: encryptedMessage.date)
    }

    private static func process(_ messageContent: Message, channel: Storage.Channel, date: Date) throws {
        switch messageContent {
        case .text(let content):
            let message = try Storage.shared.createTextMessage(content.body,
                                                                in: channel,
                                                                isIncoming: true,
                                                                date: date)

            self.postNotification(about: message)

        case .callOffer(_), .callAnswer(_), .iceCandidate(_):
            //  FIXME: Unify the handling approach for '.text' as well.
            Notifications.post(messageContent: messageContent)
        }
    }

    private static func migrationSafeContentImport(from data: Data,
                                                   version: EncryptedMessageVersion) throws -> Message {
        let messageContent: Message

        switch version {
        case .v1:
            let string = String(data: data, encoding: .utf8)!
            let textContent = Message.Text(body: string)
            messageContent = Message.text(textContent)
        case .v2:
            messageContent = try Message.import(from: data)
        }

        return messageContent
    }

    private static func setupCoreChannel(name: String) throws -> Storage.Channel {
        let channel: Storage.Channel

        if let coreChannel = Storage.shared.getChannel(withName: name) {
            channel = coreChannel
        }
        else {
            let card = try Virgil.ethree.findUser(with: name).startSync().get()

            channel = try Storage.shared.getChannel(withName: name)
                ?? Storage.shared.createSingleChannel(initiator: name, card: card)
        }

        return channel
    }

    private static func decrypt(_ message: EncryptedMessage, from channel: Storage.Channel) throws -> Data {
        let decrypted: Data

        do {
            decrypted = try Virgil.ethree.authDecrypt(data: message.ciphertext, from: channel.getCard())
        }
        catch {
            // TODO: check if needed
            try Storage.shared.createEncryptedMessage(in: channel, isIncoming: true, date: message.date)

            throw error
        }

        return decrypted
    }

    private static func postNotification(about message: Storage.Message) {
        guard Storage.shared.currentChannel != nil else {
            return Notifications.post(.chatListUpdated)
        }

        Notifications.post(message: message)
    }
}
