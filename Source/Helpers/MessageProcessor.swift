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
        } catch {
            try CoreData.shared.createEncryptedMessage(in: channel, isIncoming: true, date: message.date)
            // FIXME
            return nil
        }
        
        let content = try MessageContent.import(from: decrypted)
        
        let textMessage: String
        
        switch content {
        case .text(let textContent):
            textMessage = textContent.body
        case .sdp:
            textMessage = decrypted
        case .iceCandidate:
            textMessage = decrypted
        }

        return try CoreData.shared.createTextMessage(textMessage, in: channel, isIncoming: true, date: message.date)
    }
}
