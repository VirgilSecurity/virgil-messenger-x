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

class MessageProcessor {
    static func process(message: TCHMessage, from twilioChannel: TCHChannel) throws -> Message? {
        let isIncoming = message.author == TwilioHelper.shared.username ? false : true
        let name = TwilioHelper.shared.getName(of: twilioChannel)

        guard let date = message.dateUpdatedAsDate,
            // FIXME
            let channel = CoreDataHelper.shared.getChannel(withName: name) else {
                throw NSError()
        }

        if message.hasMedia() {
            return try self.processMedia(message: message,
                                         date: date,
                                         isIncoming: isIncoming,
                                         channel: channel)
        } else if let body = message.body,
            let rawAttributes = message.attributes(),
            let attributes = try? TwilioHelper.MessageAttributes.import(rawAttributes) {
                return try self.processText(body: body,
                                            date: date,
                                            isIncoming: isIncoming,
                                            twilioMessage: message,
                                            twilioChannel: twilioChannel,
                                            channel: channel,
                                            attributes: attributes)
        } else {
            throw NSError()
        }
    }

    private static func decrypt(_ text: String,
                                channel: Channel,
                                author: String,
                                attributes: TwilioHelper.MessageAttributes) throws -> String {
        switch channel.type {
        case .single:
            return try VirgilHelper.shared.decrypt(text, from: channel.cards.first!)
        case .group:
            guard let sessionId = attributes.sessionId else {
                throw NSError()
            }

            return try VirgilHelper.shared.decryptGroup(text, from: author, channel: channel, sessionId: sessionId)
        }
    }

    private static func processText(body: String,
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
                decrypted = try MessageProcessor.decrypt(body,
                                                         channel: channel,
                                                         author: twilioMessage.author!,
                                                         attributes: attributes)
            } catch {
                let encryptedMessage = try CoreDataHelper.shared.createTextMessage("Message encrypted",
                                                                                   in: channel,
                                                                                   isIncoming: isIncoming)
                try CoreDataHelper.shared.save(encryptedMessage)

                return encryptedMessage
            }

            let message = try CoreDataHelper.shared.createTextMessage(decrypted, in: channel, isIncoming: isIncoming, date: date)
            try CoreDataHelper.shared.save(message)

            return message
        case .service:
            guard let messages = twilioChannel.messages else {
                throw NSError()
            }

            switch channel.type {
            case .single:
                let decrypted: String
                do {
                    decrypted = try MessageProcessor.decrypt(body,
                                                             channel: channel,
                                                             author: twilioMessage.author!,
                                                             attributes: attributes)
                } catch {
                    let encryptedMessage = try CoreDataHelper.shared.createTextMessage("Message encrypted",
                                                                                       in: channel,
                                                                                       isIncoming: isIncoming)
                    try CoreDataHelper.shared.save(encryptedMessage)

                    return encryptedMessage
                }

                let serviceMessage = try ServiceMessage.import(decrypted)

                try TwilioHelper.shared.delete(twilioMessage, from: messages).startSync().getResult()

                try CoreDataHelper.shared.save(serviceMessage, to: channel)

                Log.debug("Service message received and saved")

                return nil
            case .group:
                guard let sessionId = attributes.sessionId else {
                    throw NSError()
                }

                if let serviceMessage = try CoreDataHelper.shared.findServiceMessage(from: twilioMessage.author!,
                                                                                     withSessionId: sessionId,
                                                                                     identifier: attributes.identifier) {
                    if let session = VirgilHelper.shared.getGroupSession(of: channel) {
                        if serviceMessage.cardsRemove.contains(where: { $0.identity == TwilioHelper.shared.username}) {
                            CoreDataHelper.shared.delete(serviceMessage)
                            try session.sessionStorage.deleteSession(identifier: session.identifier)
                            
                            if !CoreDataHelper.shared.existsServiceMessages(from: twilioMessage.author!, withSessionId: sessionId) {
                                CoreDataHelper.shared.delete(serviceMessage)
                                CoreDataHelper.shared.delete(channel: channel)

                                try TwilioHelper.shared.leave(twilioChannel).startSync().getResult()

                                return nil
                            }
                        } else {
                            let removeCardIds = serviceMessage.cardsRemove.map { $0.identifier }

                            try session.useChangeMembersTicket(ticket: serviceMessage.message,
                                                               addCards: serviceMessage.cardsAdd,
                                                               removeCardIds: removeCardIds)
                            try session.sessionStorage.storeSession(session)

                            CoreDataHelper.shared.add(serviceMessage.cardsAdd, to: channel)
                            CoreDataHelper.shared.remove(serviceMessage.cardsRemove, from: channel)

                            let membersCards = serviceMessage.cardsAdd.filter {
                                !CoreDataHelper.shared.existsSingleChannel(with: $0.identity) && $0.identity != TwilioHelper.shared.username
                            }
                            let members = membersCards.map { $0.identity }

                            CoreDataHelper.shared.delete(serviceMessage)

                            try ChatsManager.makeStartSingleOperation(with: members).startSync().getResult()
                        }
                    } else {
                        let session = try VirgilHelper.shared.secureChat.startGroupSession(with: serviceMessage.cards, using: serviceMessage.message)
                        try session.sessionStorage.storeSession(session)

                        CoreDataHelper.shared.add(serviceMessage.cardsAdd, to: channel)
                        CoreDataHelper.shared.remove(serviceMessage.cardsRemove, from: channel)

                        let membersCards = serviceMessage.cardsAdd.filter {
                            !CoreDataHelper.shared.existsSingleChannel(with: $0.identity) && $0.identity != TwilioHelper.shared.username }
                        let members = membersCards.map { $0.identity }

                        CoreDataHelper.shared.delete(serviceMessage)

                        try ChatsManager.makeStartSingleOperation(with: members).startSync().getResult()
                    }
                }

                let decrypted: String
                do {
                    decrypted = try MessageProcessor.decrypt(body,
                                                             channel: channel,
                                                             author: twilioMessage.author!,
                                                             attributes: attributes)
                } catch {
                    let encryptedMessage = try CoreDataHelper.shared.createTextMessage("Message encrypted",
                                                                                       in: channel,
                                                                                       isIncoming: isIncoming)
                    try CoreDataHelper.shared.save(encryptedMessage)

                    return encryptedMessage
                }

                let message = try CoreDataHelper.shared.createChangeMembersMessage(decrypted,
                                                                                   in: channel,
                                                                                   isIncoming: isIncoming,
                                                                                   date: date)

                try CoreDataHelper.shared.save(message)

                return message
            }
        }
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

        let message = try CoreDataHelper.shared.createMediaMessage(data, in: channel, isIncoming: isIncoming, date: date, type: type)
        try CoreDataHelper.shared.save(message)

        return message
    }
}
