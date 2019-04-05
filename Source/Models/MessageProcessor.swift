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
    static func process(message: TCHMessage, from twilioChannel: TCHChannel) throws -> Message {
        let isIncoming = message.author == TwilioHelper.shared.username ? false : true

        guard let date = message.dateUpdatedAsDate,
            let name = TwilioHelper.shared.getName(of: twilioChannel),
            // FIXME
            let channel = CoreDataHelper.shared.getChannel(withName: name) else {
                throw NSError()
        }

        channel.lastMessagesDate = date

        if message.hasMedia() {
            return try self.processMedia(message: message, date: date, isIncoming: isIncoming, channel: channel)
        } else if let body = message.body {
            return try self.processText(message: message, body: body, date: date, isIncoming: isIncoming, channel: channel)
        } else {
            throw NSError()
        }
    }

    private static func processText(message: TCHMessage,
                                    body: String,
                                    date: Date,
                                    isIncoming: Bool,
                                    channel: Channel) throws -> Message  {
        guard let decrypted = try? VirgilHelper.shared.decrypt(body, withCard: channel.cards.first) else {
            throw NSError()
        }

        let message = try CoreDataHelper.shared.createTextMessage(decrypted, in: channel, isIncoming: isIncoming, date: date)
        try CoreDataHelper.shared.saveMessage(message, to: channel)

        return message
    }

    private static func processMedia(message: TCHMessage,
                                     date: Date,
                                     isIncoming: Bool,
                                     channel: Channel) throws -> Message {
        guard let rawValue = message.mediaType,
            let mediaType = TwilioHelper.MediaType(rawValue: rawValue),
            let type = CoreDataHelper.MessageType(mediaType) else {
                throw NSError()
        }

        let data = try TwilioHelper.shared.makeGetMediaOperation(message: message).startSync().getResult()

        let message = try CoreDataHelper.shared.createMediaMessage(data, in: channel, isIncoming: isIncoming, date: date, type: type)
        try CoreDataHelper.shared.saveMessage(message, to: channel)

        return message
    }
}
