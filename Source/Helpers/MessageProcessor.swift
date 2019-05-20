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

    private static func processText(body: String,
                                    date: Date,
                                    isIncoming: Bool,
                                    twilioMessage: TCHMessage,
                                    twilioChannel: TCHChannel,
                                    channel: Channel,
                                    attributes: TwilioHelper.MessageAttributes) throws -> Message? {
        let decrypted: String

        do {
            switch channel.type {
            case .single:
                decrypted = try VirgilHelper.shared.decrypt(body, from: channel.cards.first!)
            case .group:
                guard let sessionId = attributes.sessionId else {
                    throw NSError()
                }

                decrypted = try VirgilHelper.shared.decryptGroup(body, from: twilioMessage.author!, channel: channel, sessionId: sessionId)
            }
        } catch {
            Log.error("AAA: \(error.localizedDescription)")
            let encryptedMessage = try CoreDataHelper.shared.createTextMessage("Message encrypted",
                                                                               in: channel,
                                                                               isIncoming: isIncoming)
            try CoreDataHelper.shared.save(encryptedMessage)

            return encryptedMessage
        }

        switch attributes.type {
        case .regular:
            let message = try CoreDataHelper.shared.createTextMessage(decrypted, in: channel, isIncoming: isIncoming, date: date)
            try CoreDataHelper.shared.save(message)

            return message
        case .service:
            guard let messages = twilioChannel.messages else {
                throw NSError()
            }

            switch channel.type {
            case .single:
                let serviceMessage = try ServiceMessage.import(decrypted)

                try TwilioHelper.shared.delete(twilioMessage, from: messages).startSync().getResult()

                try CoreDataHelper.shared.save(serviceMessage, to: channel)

                Log.debug("Service message received and saved")

                return nil
            case .group:
                let message = try CoreDataHelper.shared.createChangeMembersMessage(decrypted,
                                                                                   in: channel,
                                                                                   isIncoming: isIncoming,
                                                                                   date: date)

                try CoreDataHelper.shared.save(message)

                // Find Service Message in DM, update and resave Virgil Ratchet session

                guard let sessionId = attributes.sessionId else {
                    throw NSError()
                }

                let serviceMessage = try CoreDataHelper.shared.findServiceMessage(from: twilioMessage.author!,
                                                                                  type: .changeMembers,
                                                                                  withSessionId: sessionId)!

                guard let session = VirgilHelper.shared.getGroupSession(of: channel) else {
                    throw NSError()
                }

                try session.useChangeMembersTicket(ticket: serviceMessage.message,
                                                   addCards: serviceMessage.cardsAdd,
                                                   removeCardIds: [])
                try session.sessionStorage.storeSession(session)

                CoreDataHelper.shared.delete(serviceMessage: serviceMessage)

                let membersCards = serviceMessage.cardsAdd.filter { !CoreDataHelper.shared.existsSingleChannel(with: $0.identity) }

                try CoreDataHelper.shared.makeAddOperation(membersCards, to: channel).startSync().getResult()

                let members = membersCards.map { $0.identity }

                try ChatsManager.makeStartSingleOperation(with: members).startSync().getResult()

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
