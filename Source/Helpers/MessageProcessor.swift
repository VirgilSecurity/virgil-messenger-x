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
        let isIncoming = message.author == TwilioHelper.shared.username ? false : true

        guard let date = message.dateUpdatedAsDate, let index = message.index else {
            throw TwilioHelperError.invalidMessage
        }

        guard let channel = CoreDataHelper.shared.getChannel(twilioChannel) else {
            throw CoreDataHelperError.channelNotFound
        }

        guard (Int(truncating: index) >= channel.messages.count) else {
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
            throw TwilioHelperError.invalidMessage
        }
    }

    private static func processText(_ text: String,
                                    date: Date,
                                    isIncoming: Bool,
                                    twilioMessage: TCHMessage,
                                    twilioChannel: TCHChannel,
                                    channel: Channel) throws -> Message? {
        let attributes = try TwilioHelper.MessageAttributes.import(twilioMessage.attributes()!)

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
                                      attributes: TwilioHelper.MessageAttributes) throws -> Message? {
        switch attributes.type {
        case .regular:
            let decrypted: String
            do {
                decrypted = try VirgilHelper.shared.decrypt(text, from: channel.cards.first!)
            } catch {
                return try CoreDataHelper.shared.createEncryptedMessage(in: channel, isIncoming: isIncoming, date: date)
            }

            return try CoreDataHelper.shared.createTextMessage(decrypted, in: channel, isIncoming: isIncoming, date: date)
        case .service:
            if twilioMessage.author == TwilioHelper.shared.username {
                return nil
            }

            let decrypted: String
            do {
                decrypted = try VirgilHelper.shared.decrypt(text, from: channel.cards.first!)
            } catch {
                return try CoreDataHelper.shared.createEncryptedMessage(in: channel, isIncoming: isIncoming, date: date)
            }

            let serviceMessage = try ServiceMessage.import(decrypted)

            try TwilioHelper.shared.delete(twilioMessage, from: twilioChannel.messages!).startSync().getResult()

            try CoreDataHelper.shared.save(serviceMessage, to: channel)

            return nil
        }
    }

    private static func processGroup(text: String,
                                     date: Date,
                                     isIncoming: Bool,
                                     twilioMessage: TCHMessage,
                                     twilioChannel: TCHChannel,
                                     channel: Channel,
                                     attributes: TwilioHelper.MessageAttributes) throws -> Message? {
        guard let sessionId = channel.sessionId else {
            throw CoreDataHelperError.invalidChannel
        }

        switch attributes.type {
        case .regular:
            var decrypted: String
            do {
                decrypted = try VirgilHelper.shared.decryptGroup(text, from: twilioMessage.author!, channel: channel, sessionId: sessionId)
            } catch {
                return try CoreDataHelper.shared.createEncryptedMessage(in: channel, isIncoming: isIncoming, date: date)
            }

            decrypted = "\(twilioMessage.author!): \(decrypted)"

            return try CoreDataHelper.shared.createTextMessage(decrypted, in: channel, isIncoming: isIncoming, date: date)
        case .service:
            guard let serviceMessage = try CoreDataHelper.shared.findServiceMessage(from: twilioMessage.author!,
                                                                                    withSessionId: sessionId,
                                                                                    identifier: attributes.identifier) else {
                return try CoreDataHelper.shared.createEncryptedMessage(in: channel, isIncoming: isIncoming, date: date)
            }

            let text = "\(twilioMessage.author!) \(try serviceMessage.getChangeMembersText())"

            let deleted = try self.processGroupServiceMessage(serviceMessage,
                                                              from: twilioMessage.author!,
                                                              isIncoming: isIncoming,
                                                              sessionId: sessionId,
                                                              twilioChannel: twilioChannel,
                                                              channel: channel)

            return deleted ? nil : try CoreDataHelper.shared.createChangeMembersMessage(text,
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
        guard !serviceMessage.cardsRemove.contains(where: { $0.identity == TwilioHelper.shared.username}) else {
            try CoreDataHelper.shared.delete(serviceMessage)

            if let session = VirgilHelper.shared.getGroupSession(of: channel) {
                try VirgilHelper.shared.secureChat.deleteGroupSession(sessionId: session.identifier)
            }

            if !CoreDataHelper.shared.existsServiceMessage(from: author, withSessionId: sessionId) {
                try TwilioHelper.shared.leave(twilioChannel).startSync().getResult()

                if CoreDataHelper.shared.currentChannel == channel {
                    DispatchQueue.main.async {
                        let name = Notification.Name(rawValue: TwilioHelper.Notifications.ChannelDeleted.rawValue)
                        NotificationCenter.default.post(name: name, object: self)
                    }
                }

                return true
            }

            return false
        }

        try VirgilHelper.shared.updateParticipants(serviceMessage: serviceMessage, channel: channel)

        try CoreDataHelper.shared.add(serviceMessage.cardsAdd, to: channel)
        try CoreDataHelper.shared.remove(serviceMessage.cardsRemove, from: channel)

        let membersCards = serviceMessage.cardsAdd.filter {
            !CoreDataHelper.shared.existsSingleChannel(with: $0.identity) && $0.identity != TwilioHelper.shared.username
        }
        let members = membersCards.map { $0.identity }

        try? ChatsManager.startSingle(with: members)

        try CoreDataHelper.shared.delete(serviceMessage)

        return false
    }

    private static func processMedia(message: TCHMessage,
                                     date: Date,
                                     isIncoming: Bool,
                                     channel: Channel) throws -> Message {
        guard let rawValue = message.mediaType,
            let mediaType = TwilioHelper.MediaType(rawValue: rawValue),
            let type = MessageType(mediaType) else {
                throw NSError()
        }

        let data = try TwilioHelper.shared.makeGetMediaOperation(message: message).startSync().getResult()

        return try CoreDataHelper.shared.createMediaMessage(data, in: channel, isIncoming: isIncoming, date: date, type: type)
    }
}
