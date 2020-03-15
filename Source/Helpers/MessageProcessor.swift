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
    
    private static func process(_ messageContent: MessageContent, channel: Channel, date: Date) throws {
        let message: Message
    
        switch messageContent {
        case .text(let textContent):
            message = try CoreData.shared.createTextMessage(with: textContent,
                                                            in: channel,
                                                            isIncoming: true,
                                                            date: date)
            
        case .photo(let photoContent):
            message = try CoreData.shared.createPhotoMessage(with: photoContent,
                                                             in: channel,
                                                             isIncoming: true,
                                                             date: date)
        }
        
        self.postNotification(about: message)
    }
    
    private static func migrationSafeContentImport(from string: String,
                                                   version: EncryptedMessageVersion) throws -> MessageContent {
        let messageContent: MessageContent
        
        switch version {
        case .v1:
            let textContent = TextContent(body: string)
            messageContent = MessageContent.text(textContent)
        case .v2:
            messageContent = try MessageContent.import(from: string)
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
    
    private static func decrypt(_ message: EncryptedMessage, from channel: Channel) throws -> String {
        let decrypted: String
        
        do {
            decrypted = try Virgil.ethree.authDecrypt(text: message.ciphertext, from: channel.getCard())
        }
        catch {
            // TODO: check if needed
            try CoreData.shared.createEncryptedMessage(in: channel, isIncoming: true, date: message.date)
            
            throw error
        }
        
        return decrypted
    }
    
    private static func postNotification(about message: Message) {
        guard CoreData.shared.currentChannel != nil else {
            return Notifications.post(.chatListUpdated)
        }
    
        Notifications.post(message: message)
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
