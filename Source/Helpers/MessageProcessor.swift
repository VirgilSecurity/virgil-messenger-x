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
                                        twilioChannel: twilioChannel,
                                        channel: channel)
        } else {
            throw Twilio.Error.invalidMessage
        }
    }

    private static func processText(_ text: String,
                                    date: Date,
                                    isIncoming: Bool,
                                    twilioMessage: TCHMessage,
                                    twilioChannel: TCHChannel,
                                    channel: Channel) throws -> Message? {
        let attributes = try twilioMessage.getAttributes()

        switch channel.type {
        case .single:
            return try self.processSingle(text: text,
                                          date: date,
                                          isIncoming: isIncoming,
                                          twilioMessage: twilioMessage,
                                          twilioChannel: twilioChannel,
                                          channel: channel,
                                          attributes: attributes)
        case .group:
            return try self.processGroup(text: text,
                                         date: date,
                                         isIncoming: isIncoming,
                                         twilioMessage: twilioMessage,
                                         twilioChannel: twilioChannel,
                                         channel: channel,
                                         attributes: attributes)
        }
    }

    private static func processSingle(text: String,
                                      date: Date,
                                      isIncoming: Bool,
                                      twilioMessage: TCHMessage,
                                      twilioChannel: TCHChannel,
                                      channel: Channel,
                                      attributes: TCHMessage.Attributes) throws -> Message? {
        switch attributes.type {
        case .regular:
            let decrypted: String
            do {
                decrypted = try Virgil.shared.decrypt(text, from: channel.cards.first!)
            } catch {
                try CoreData.shared.createEncryptedMessage(in: channel, isIncoming: isIncoming, date: date)

                return nil
            }

            return try CoreData.shared.createTextMessage(decrypted, in: channel, isIncoming: isIncoming, date: date)
        case .service:
            if twilioMessage.author == Twilio.shared.identity {
                return nil
            }

            let decrypted: String
            do {
                decrypted = try Virgil.shared.decrypt(text, from: channel.cards.first!)
            } catch {
                try CoreData.shared.createEncryptedMessage(in: channel, isIncoming: isIncoming, date: date)
                return nil
            }

            let serviceMessage = try ServiceMessage.import(decrypted)

            try twilioChannel.delete(message: twilioMessage).startSync().getResult()

            try CoreData.shared.save(serviceMessage, to: channel)

            return nil
        }
    }

    private static func processGroup(text: String,
                                     date: Date,
                                     isIncoming: Bool,
                                     twilioMessage: TCHMessage,
                                     twilioChannel: TCHChannel,
                                     channel: Channel,
                                     attributes: TCHMessage.Attributes) throws -> Message? {
        let sessionId = try channel.getSessionId()

        let author = try twilioMessage.getAuthor()

        switch attributes.type {
        case .regular:
            var decrypted: String
            do {
                decrypted = try Virgil.shared.decryptGroup(text, from: author, channel: channel, sessionId: sessionId)
            } catch {
                try CoreData.shared.createEncryptedMessage(in: channel, isIncoming: isIncoming, date: date)
                return nil
            }

            decrypted = "\(author): \(decrypted)"

            return try CoreData.shared.createTextMessage(decrypted, in: channel, isIncoming: isIncoming, date: date)
        case .service:
            guard let serviceMessage = try CoreData.shared.findServiceMessage(from: author,
                                                                                    withSessionId: sessionId,
                                                                                    identifier: attributes.identifier) else {
                try CoreData.shared.createEncryptedMessage(in: channel, isIncoming: isIncoming, date: date)
                return nil
            }

            let text = "\(author) \(try serviceMessage.getChangeMembersText())"

            let deleted = try self.processGroupServiceMessage(serviceMessage,
                                                              from: author,
                                                              isIncoming: isIncoming,
                                                              sessionId: sessionId,
                                                              twilioChannel: twilioChannel,
                                                              channel: channel)

            return deleted ? nil : try CoreData.shared.createChangeMembersMessage(text,
                                                                                        in: channel,
                                                                                        isIncoming: isIncoming,
                                                                                        date: date)
        }
    }

    private static func processGroupServiceMessage(_ serviceMessage: ServiceMessage,
                                                   from author: String,
                                                   isIncoming: Bool,
                                                   sessionId: Data,
                                                   twilioChannel: TCHChannel,
                                                   channel: Channel) throws -> Bool {
        guard !serviceMessage.cardsRemove.contains(where: { $0.identity == Twilio.shared.identity}) else {
            try CoreData.shared.delete(serviceMessage)

            if let session = Virgil.shared.getGroupSession(of: channel) {
                try Virgil.shared.secureChat.deleteGroupSession(sessionId: session.identifier)
            }

            guard CoreData.shared.existsServiceMessage(from: author, withSessionId: sessionId) else {
                try Twilio.shared.leave(twilioChannel).startSync().getResult()

                if CoreData.shared.currentChannel == channel {
                    DispatchQueue.main.async {
                        let name = Notification.Name(rawValue: Twilio.Notifications.ChannelDeleted.rawValue)
                        NotificationCenter.default.post(name: name, object: self)
                    }
                }

                return true
            }

            return false
        }

        try Virgil.shared.updateParticipants(serviceMessage: serviceMessage, channel: channel)

        try CoreData.shared.add(serviceMessage.cardsAdd, to: channel)
        try CoreData.shared.remove(serviceMessage.cardsRemove, from: channel)

        let membersCards = serviceMessage.cardsAdd.filter {
            !CoreData.shared.existsSingleChannel(with: $0.identity) && $0.identity != Twilio.shared.identity
        }
        let members = membersCards.map { $0.identity }

        try? ChatsManager.startSingle(with: members)

        try CoreData.shared.delete(serviceMessage)

        return false
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

        let data = try message.getMedia().startSync().getResult()

        return try CoreData.shared.createMediaMessage(data, in: channel, isIncoming: isIncoming, date: date, type: type)
    }
}
