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

    static func processGlobalReadState(from author: String) throws {
        let channel = try self.setupChannel(name: author)

        let messagesToUpdateIds = try Storage.shared.markDeliveredMessagesAsRead(in: channel)

        if let channel = Storage.shared.currentChannel, channel.name == author {
            Notifications.post(newState: .read, messageIds: messagesToUpdateIds)
        }
    }

    static func processNewMessageState(_ state: Storage.Message.State, withId receiptId: String, from author: String) throws {
        let channel = try self.setupChannel(name: author)

        let newState = try Storage.shared.updateMessageState(to: state, withId: receiptId, from: channel)

        if let channel = Storage.shared.currentChannel, channel.name == author {
            Notifications.post(newState: newState, messageIds: [receiptId])
        }
    }

    static func process(_ encryptedMessage: EncryptedMessage, from author: String, xmppId: String) throws {
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
                         xmppId: xmppId,
                         channel: channel,
                         author: author,
                         date: encryptedMessage.date)
    }

    static func process(call encryptedMessage: EncryptedMessage, from caller: String) throws {
        let channel = try self.setupCoreChannel(name: caller)

        let decrypted = try self.decrypt(encryptedMessage, from: channel)

        let message = try self.migrationSafeContentImport(from: decrypted,
                                                       version: encryptedMessage.modelVersion)

        switch message {
        case .callOffer(let callOffer):
            let xmppId = callOffer.callUUID.uuidString

            try self.process(message,
                             additionalData: nil,
                             xmppId: xmppId,
                             channel: channel,
                             author: caller,
                             date: encryptedMessage.date)

        default:
            break
        }
    }

    private static func process(_ message: NetworkMessage,
                                additionalData: Data?,
                                xmppId: String,
                                channel: Storage.Channel,
                                author: String,
                                date: Date) throws {

        var unread: Bool = true
        if let channel = Storage.shared.currentChannel, channel.name == author {
            unread = false
        }

        let baseParams = Storage.Message.Params(xmppId: xmppId, isIncoming: true, channel: channel, state: .received, date: date)

        var storageMessage: Storage.Message?

        switch message {
        case .text(let text):
            storageMessage = try Storage.shared.createTextMessage(with: text,
                                                                  unread: unread,
                                                                  baseParams: baseParams)

        case .photo(let photo):
            guard let thumbnail = additionalData else {
                throw Error.missingThumbnail
            }

            storageMessage = try Storage.shared.createPhotoMessage(with: photo,
                                                                   thumbnail: thumbnail,
                                                                   unread: unread,
                                                                   baseParams: baseParams)
        case .voice(let voice):
            storageMessage = try Storage.shared.createVoiceMessage(with: voice,
                                                                   unread: unread,
                                                                   baseParams: baseParams)

        case .callOffer(let callOffer):

            if channel.containsCallMessage(with: callOffer.callUUID) {
                Log.debug("CallOffer was already processed (callUUID = \(callOffer.callUUID))")
                return
            }

            Notifications.post(message: message)

            storageMessage = try Storage.shared.createCallMessage(with: callOffer,
                                                                  unread: unread,
                                                                  baseParams: baseParams)

        case .callAnswer, .callUpdate, .iceCandidate:
            //  TODO: Unify the handling approach for '.text' as well.
            Notifications.post(message: message)
        }

        guard let channel = Storage.shared.currentChannel,
            channel.name == author else {
                return Notifications.post(.chatListUpdated)
        }

        if let storageMessage = storageMessage {
            self.postNotification(about: storageMessage, unread: unread)
        }

        self.postLocalPushNotification(message: message, author: author)
    }

    private static func migrationSafeContentImport(from data: Data,
                                                   version: EncryptedMessageVersion) throws -> NetworkMessage {
        let message: NetworkMessage

        switch version {
        case .v1:
            guard let body = String(data: data, encoding: .utf8) else {
                throw Error.dataToStrFailed
            }

            let text = NetworkMessage.Text(body: body)
            message = NetworkMessage.text(text)
        case .v2:
            message = try NetworkMessage.import(from: data)
        }

        return message
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

    private static func postNotification(about message: Storage.Message, unread: Bool) {
        unread ? Notifications.post(.chatListUpdated) : Notifications.post(message: message)
    }

    private static func postLocalPushNotification(message: NetworkMessage, author: String) {
        let currentChannelName = Storage.shared.currentChannel?.name
        guard currentChannelName != nil && currentChannelName != author else {
            return
        }

        PushNotifications.post(message: message, author: author)
    }

    private static func setupChannel(name: String) throws -> Storage.Channel {
        let channel: Storage.Channel

        if let coreChannel = Storage.shared.getChannel(withName: name) {
            channel = coreChannel
        }
        else {
            let card = try Virgil.ethree.findUser(with: name)
                .startSync()
                .get()

            channel = try Storage.shared.createSingleChannel(initiator: name, card: card)
        }

        return channel
    }
}
