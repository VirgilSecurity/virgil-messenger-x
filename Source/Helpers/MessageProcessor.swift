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
    static func process(_ message: EncryptedMessage, from author: String) throws -> Message? {
        let channel = try self.setupChannel(name: author)

        let decrypted: String
        do {
            decrypted = try Virgil.ethree.authDecrypt(text: message.ciphertext, from: channel.getCard())
        }
        catch {
            try CoreData.shared.createEncryptedMessage(in: channel, isIncoming: true, date: message.date)
            // FIXME
            return nil
        }
        
        let messageContent = try MessageContent.import(decrypted)
        
        switch messageContent.type {
        case .text:
            guard let body = messageContent.body else {
                throw NSError()
            }
            
            return try CoreData.shared.createTextMessage(body, in: channel, isIncoming: true, date: message.date)
        case .photo, .audio:
            guard let mediaHash = messageContent.mediaHash,
                let mediaURL = messageContent.mediaUrl else {
                    throw NSError()
            }
            
            // Check hash in local storage
            
            // Download and decrypt photo from server
            try Virgil.shared.client.downloadFile(from: mediaURL) { tempFileUrl in
                let path = try CoreData.shared.getMediaStorage().getPath(name: mediaHash)
                
                guard let inputStream = InputStream(url: tempFileUrl) else {
                    throw NSError()
                }

                guard let outputStream = OutputStream(toFileAtPath: path, append: false) else {
                    throw NSError()
                }
                
                let data = try Data(contentsOf: tempFileUrl)
                
                try Virgil.ethree.authDecrypt(inputStream, to: outputStream, from: channel.getCard())
            }
            
            return try CoreData.shared.createMediaMessage(type: messageContent.type,
                                                          in: channel,
                                                          mediaHash: mediaHash,
                                                          mediaUrl: mediaURL,
                                                          isIncoming: true)
        }
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
