//
//  MessageProcessor.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/3/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import Foundation

class MessageProcessor {
    enum Error: Swift.Error {
        case missingThumbnail
        case dataToStrFailed
    }

    static func process(_ encryptedMessage: EncryptedMessage, from author: String) throws {
        let channel = try self.setupCoreChannel(name: author)

        let decrypted = try self.decrypt(encryptedMessage, from: channel)

        var decryptedAdditional: Data?

        if let data = encryptedMessage.additionalData {
            decryptedAdditional = try Virgil.ethree.authDecrypt(data: data, from: channel.getCard())
        }

        let message = try self.migrationSafeContentImport(from: decrypted,
                                                                 version: encryptedMessage.modelVersion)

        try self.process(message,
                         additionalData: decryptedAdditional,
                         channel: channel,
                         author: author,
                         date: encryptedMessage.date)
    }

    private static func process(_ message: Message,
                                additionalData: Data?,
                                channel: Storage.Channel,
                                author: String,
                                date: Date) throws {

        var storageMessage: Storage.Message?

        switch message {
        case .text(let text):
            storageMessage = try Storage.shared.createTextMessage(text,
                                                                in: channel,
                                                                isIncoming: true,
                                                                date: date)

        case .photo(let photo):
            guard let thumbnail = additionalData else {
                throw Error.missingThumbnail
            }

            storageMessage = try Storage.shared.createPhotoMessage(photo,
                                                             thumbnail: thumbnail,
                                                             in: channel,
                                                             isIncoming: true,
                                                             date: date)

        case .voice(let voice):
            storageMessage = try Storage.shared.createVoiceMessage(voice,
                                                             in: channel,
                                                             isIncoming: true,
                                                             date: date)

        case .callOffer:
            Notifications.post(message: message)

            storageMessage = try Storage.shared.createCallMessage(in: channel,
                                                                isIncoming: true,
                                                                date: date)

        case .callAnswer, .iceCandidate:
            //  FIXME: Unify the handling approach for '.text' as well.
            Notifications.post(message: message)
        }

        guard let channel = Storage.shared.currentChannel,
            channel.name == author else {
                return Notifications.post(.chatListUpdated)
        }

        if let storageMessage = storageMessage {
            Notifications.post(message: storageMessage)
        }
    }

    private static func migrationSafeContentImport(from data: Data,
                                                   version: EncryptedMessageVersion) throws -> Message {
        let message: Message

        switch version {
        case .v1:
            guard let body = String(data: data, encoding: .utf8) else {
                throw Error.dataToStrFailed
            }

            let text = Message.Text(body: body)
            message = Message.text(text)
        case .v2:
            message = try Message.import(from: data)
        }

        return message
    }

    private static func setupCoreChannel(name: String) throws -> Storage.Channel {
        let channel: Storage.Channel

        if let coreChannel = Storage.shared.getChannel(withName: name) {
            channel = coreChannel
        } else {
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
        } catch {
            // TODO: check if needed
            try Storage.shared.createEncryptedMessage(in: channel, isIncoming: true, date: message.date)

            throw error
        }

        return decrypted
    }

    private static func setupChannel(name: String) throws -> Storage.Channel {
        let channel: Storage.Channel

        if let coreChannel = Storage.shared.getChannel(withName: name) {
            channel = coreChannel
        } else {
            let card = try Virgil.ethree.findUser(with: name)
                .startSync()
                .get()

            channel = try Storage.shared.getChannel(withName: name)
                ?? Storage.shared.createSingleChannel(initiator: name, card: card)
        }

        return channel
    }
}
