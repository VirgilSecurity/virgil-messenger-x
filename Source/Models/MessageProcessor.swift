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
        switch attributes.type {
        case .regular:
            // FIXME
            var decrypted: String = body
            if channel.type == .single {
                decrypted = try VirgilHelper.shared.decrypt(body, from: channel.cards.first!)
            }

            let message = try CoreDataHelper.shared.createTextMessage(decrypted, in: channel, isIncoming: isIncoming, date: date)
            try CoreDataHelper.shared.save(message)

            return message
        case .service:
            let decrypted = try VirgilHelper.shared.decrypt(body, from: channel.cards.first!)

            guard let message = Data(base64Encoded: decrypted) else {
                throw NSError()
            }

            // FIXME
            twilioChannel.messages?.remove(twilioMessage) { result in
                if let error = result.error {
                    Log.debug("Service Message remove: \(error.description)")
                }
            }

            try CoreDataHelper.shared.saveServiceMessage(message, to: channel, type: .startGroup)

            Log.debug("Service message received and saved")

            return nil
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
