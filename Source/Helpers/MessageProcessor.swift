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

public enum AnyMessage {
    case message(Message)
    case call(Call)
}

public enum Call {
    case sessionDescription(CallSessionDescription)
    case iceCandiadte(CallIceCandidate)
}

class MessageProcessor {
    static func process(_ message: EncryptedMessage, from author: String) throws -> AnyMessage? {
        let channel = try self.setupChannel(name: author)

        let decrypted: String
        do {
            decrypted = try Virgil.ethree.authDecrypt(text: message.ciphertext, from: channel.getCard())
        } catch {
            // FIXME
            try CoreData.shared.createEncryptedMessage(in: channel, isIncoming: true, date: message.date)
            return nil
        }
        
        let content = try MessageContent.import(from: decrypted)
        
        var resultMessage: AnyMessage?
        
        switch content {
        case .text(let textContent):
            if let coreMessage = try? CoreData.shared.createTextMessage(textContent.body, in: channel, isIncoming: true, date: message.date) {
                resultMessage = AnyMessage.message(coreMessage)
            }
            
        case .sdp(let callSessionDescription):
            resultMessage = AnyMessage.call(Call.sessionDescription(callSessionDescription))
            
        case .iceCandidate(let callIceCandidate):
            resultMessage = AnyMessage.call(Call.iceCandiadte(callIceCandidate))
        }
        
        return resultMessage
    }
    
    private static func setupChannel(name: String) throws -> Channel {
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
}
