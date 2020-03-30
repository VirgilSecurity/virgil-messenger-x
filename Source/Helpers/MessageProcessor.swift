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
        
        var decryptedAdditional: Data? = nil
        
        if let data = encryptedMessage.additionalData {
            decryptedAdditional = try Virgil.ethree.authDecrypt(data: data, from: channel.getCard())
        }
        
        let messageContent = try self.migrationSafeContentImport(from: decrypted,
                                                                 version: encryptedMessage.modelVersion)
        
        try self.process(messageContent,
                         additionalData: decryptedAdditional,
                         channel: channel,
                         author: author,
                         date: encryptedMessage.date)
    }
    
    private static func process(_ messageContent: MessageContent,
                                additionalData: Data?,
                                channel: Channel,
                                author: String,
                                date: Date) throws {
        var unread: Bool = true
        if let channel = CoreData.shared.currentChannel, channel.name == author {
            unread = false
        }
            
        let message: Message
    
        switch messageContent {
        case .text(let textContent):
            // FIXME: remove copypasting common parameters
            message = try CoreData.shared.createTextMessage(with: textContent,
                                                            unread: unread,
                                                            in: channel,
                                                            isIncoming: true,
                                                            date: date)
            
        case .photo(let photoContent):
            guard let thumbnail = additionalData else {
                throw Error.missingThumbnail
            }
            
            message = try CoreData.shared.createPhotoMessage(with: photoContent,
                                                             thumbnail: thumbnail,
                                                             unread: unread,
                                                             in: channel,
                                                             isIncoming: true,
                                                             date: date)
        case .voice(let voiceContent):
            message = try CoreData.shared.createVoiceMessage(with: voiceContent,
                                                             unread: unread,
                                                             in: channel,
                                                             isIncoming: true,
                                                             date: date)
        }

        self.postNotification(about: message, unread: unread)
        self.postLocalPushNotification(content: messageContent, author: author)
    }
    
    private static func migrationSafeContentImport(from data: Data,
                                                   version: EncryptedMessageVersion) throws -> MessageContent {
        let messageContent: MessageContent
        
        switch version {
        case .v1:
            guard let body = String(data: data, encoding: .utf8) else {
                throw Error.dataToStrFailed
            }
            
            let textContent = TextContent(body: body)
            messageContent = MessageContent.text(textContent)
        case .v2:
            messageContent = try MessageContent.import(from: data)
        }
        
        return messageContent
    }
    
    private static func setupCoreChannel(name: String) throws -> Channel {
        let channel: Channel

        if let coreChannel = CoreData.shared.getChannel(withName: name) {
            channel = coreChannel
        }
        else {
            let card = try Virgil.ethree.findUser(with: name).startSync().get()

            channel = try CoreData.shared.getChannel(withName: name)
                ?? CoreData.shared.createSingleChannel(initiator: name, card: card)
        }
        
        return channel
    }
    
    private static func decrypt(_ message: EncryptedMessage, from channel: Channel) throws -> Data {
        let decrypted: Data
        
        do {
            decrypted = try Virgil.ethree.authDecrypt(data: message.ciphertext, from: channel.getCard())
        }
        catch {
            // TODO: check if needed
            try CoreData.shared.createEncryptedMessage(in: channel, isIncoming: true, date: message.date)
            
            throw error
        }
        
        return decrypted
    }
    
    private static func postNotification(about message: Message, unread: Bool) {
        unread ? Notifications.post(.chatListUpdated) : Notifications.post(message: message)
    }

    private static func postLocalPushNotification(content: MessageContent, author: String) {
        let currentChannelName = CoreData.shared.currentChannel?.name
        guard currentChannelName != nil && currentChannelName != author else {
            return
        }

        PushNotifications.post(messageContent: content, author: author)
    }
    
    private static func setupChannel(name: String) throws -> Channel {
        let channel: Channel

        if let coreChannel = CoreData.shared.getChannel(withName: name) {
            channel = coreChannel
        }
        else {
            let card = try Virgil.ethree.findUser(with: name)
                .startSync()
                .get()

            channel = try CoreData.shared.getChannel(withName: name)
                ?? CoreData.shared.createSingleChannel(initiator: name, card: card)
        }
        
        return channel
    }
}
