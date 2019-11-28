//
//  MessageProcessor.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/3/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import TwilioChatClient
import Chatto
import ChattoAdditions
import AVFoundation
import VirgilCryptoRatchet
import VirgilSDKRatchet

class MessageProcessor {
    static func process(message: TCHMessage, from twilioChannel: TCHChannel) throws -> Message? {
        let isIncoming = message.author == Twilio.shared.identity ? false : true

        let date = try message.getDate()
        let index = try message.getIndex()

        let channel = try CoreData.shared.getChannel(twilioChannel)

        guard (Int(truncating: index) >= channel.allMessages.count) else {
            return nil
        }

        if message.hasMedia() {
            return try self.processMedia(message: message,
                                         date: date,
                                         isIncoming: isIncoming,
                                         channel: channel)
        } else if let body = message.body {
            return try self.processText(body,
                                        date: date,
                                        isIncoming: isIncoming,
                                        twilioMessage: message,
                                        channel: channel)
        } else {
            throw Twilio.Error.invalidMessage
        }
    }

    private static func processText(_ text: String,
                                    date: Date,
                                    isIncoming: Bool,
                                    twilioMessage: TCHMessage,
                                    channel: Channel) throws -> Message? {
        let attributes = try twilioMessage.getAttributes()

        switch channel.type {
        case .single:
            return try self.processSingle(text: text,
                                          date: date,
                                          isIncoming: isIncoming,
                                          channel: channel,
                                          attributes: attributes)
        case .group:
            return try self.processGroup(text: text,
                                         date: date,
                                         isIncoming: isIncoming,
                                         twilioMessage: twilioMessage,
                                         channel: channel,
                                         attributes: attributes)
        }
    }

    private static func processSingle(text: String,
                                      date: Date,
                                      isIncoming: Bool,
                                      channel: Channel,
                                      attributes: TCHMessage.Attributes) throws -> Message? {
        switch attributes.type {
        case .regular:
            let decrypted: String
            do {
                decrypted = try Virgil.ethree.authDecrypt(text: text, from: channel.cards.first)
            } catch {
                try CoreData.shared.createEncryptedMessage(in: channel, isIncoming: isIncoming, date: date)

                return nil
            }

            return try CoreData.shared.createTextMessage(decrypted, in: channel, isIncoming: isIncoming, date: date)
        case .service:
            try CoreData.shared.createEncryptedMessage(in: channel, isIncoming: isIncoming, date: date)

            return nil
        }
    }

    private static func processGroup(text: String,
                                     date: Date,
                                     isIncoming: Bool,
                                     twilioMessage: TCHMessage,
                                     channel: Channel,
                                     attributes: TCHMessage.Attributes) throws -> Message? {
        let author = try twilioMessage.getAuthor()
        let group = try channel.getGroup()
        let authorCard = try Virgil.ethree.findUser(with: author).startSync().get()

        var decrypted: String
        do {
            decrypted = try group.decrypt(text: text, from: authorCard)
        }
        catch {
            Log.debug("AAA: \(error.localizedDescription)")
            try CoreData.shared.createEncryptedMessage(in: channel, isIncoming: isIncoming, date: date)
            return nil
        }

        switch attributes.type {
        case .regular:
            decrypted = "\(author): \(decrypted)"

            return try CoreData.shared.createTextMessage(decrypted, in: channel, isIncoming: isIncoming, date: date)
        case .service:
            try group.update().startSync().get()

            decrypted = "\(author) \(decrypted)"

            let participants = try Virgil.ethree.findUsers(with: Array(group.participants)).startSync().get()
            let cards = Array(participants.values)
            try CoreData.shared.updateCards(with: cards, for: channel)

            return try CoreData.shared.createChangeMembersMessage(decrypted, in: channel, isIncoming: isIncoming, date: date)
        }
    }

    private static func processMedia(message: TCHMessage,
                                     date: Date,
                                     isIncoming: Bool,
                                     channel: Channel) throws -> Message {
        guard let rawValue = message.mediaType,
            let mediaType = Twilio.MediaType(rawValue: rawValue),
            let type = MessageType(mediaType) else {
                throw NSError()
        }

        let data = try message.getMedia().startSync().get()

        return try CoreData.shared.createMediaMessage(data, in: channel, isIncoming: isIncoming, date: date, type: type)
    }
}
