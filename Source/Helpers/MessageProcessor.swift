//
//  MessageProcessor.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/3/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import Chatto
import ChattoAdditions
import AVFoundation
import VirgilCryptoRatchet
import VirgilSDKRatchet

class MessageProcessor {
    static func process(_ encryptedMessage: EncryptedMessage, from author: String) throws {
        let channel = try self.setupCoreChannel(name: author)

        let decrypted = try self.decrypt(encryptedMessage, from: channel)
                
        let messageContent = try MessageContent.import(from: decrypted)
        
        switch messageContent {
        case .text(let content):
            let message = try CoreData.shared.createTextMessage(content.body,
                                                                in: channel,
                                                                isIncoming: true,
                                                                date: encryptedMessage.date)
            
            self.postNotification(about: message)
        }
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
}
