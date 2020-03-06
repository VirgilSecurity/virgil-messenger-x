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
        let channel: Channel

        if let coreChannel = CoreData.shared.getChannel(withName: author) {
            channel = coreChannel
        }
        else {
            let card = try Virgil.ethree.findUser(with: author).startSync().get()

            channel = try CoreData.shared.getChannel(withName: author)
                ?? CoreData.shared.createSingleChannel(initiator: author, card: card)
        }

        let decrypted: String
        do {
            decrypted = try Virgil.ethree.authDecrypt(text: message.ciphertext, from: channel.getCard())
        }
        catch {
            try CoreData.shared.createEncryptedMessage(in: channel, isIncoming: true, date: message.date)
            // FIXME
            return nil
        }
        
        let messageContent = try MessageContent.import(from: decrypted)
        
        switch messageContent {
        case .text(let content):
            return try CoreData.shared.createTextMessage(content.body, in: channel, isIncoming: true, date: message.date)
        }
    }
}
