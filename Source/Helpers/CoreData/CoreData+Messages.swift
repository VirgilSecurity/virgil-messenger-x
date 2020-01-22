//
//  CoreData+Messages.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import CoreData
import VirgilCryptoRatchet
import VirgilSDK

extension CoreData {
    private func save(_ message: Message) throws {
        let messages = message.channel.mutableOrderedSetValue(forKey: Channel.MessagesKey)
        messages.add(message)

        try self.saveContext()
    }

    func createChangeMembersMessage(_ text: String,
                                    in channel: Channel? = nil,
                                    isIncoming: Bool,
                                    date: Date = Date()) throws -> Message {
        let channel = try channel ?? self.getCurrentChannel()

        let message = try Message(body: text,
                                  type: .changeMembers,
                                  isIncoming: isIncoming,
                                  date: date,
                                  channel: channel,
                                  managedContext: self.managedContext)

        try self.save(message)

        return message
    }

    func createEncryptedMessage(in channel: Channel, isIncoming: Bool, date: Date) throws {
        let message = try Message(body: "Message encrypted",
                                  type: .text,
                                  isIncoming: isIncoming,
                                  date: date,
                                  channel: channel,
                                  isHidden: true,
                                  managedContext: self.managedContext)

        try self.save(message)
    }

    func createTextMessage(_ body: String,
                           in channel: Channel? = nil,
                           isIncoming: Bool,
                           date: Date = Date()) throws -> Message {
        let channel = try channel ?? self.getCurrentChannel()

        let message = try Message(body: body,
                                  type: .text,
                                  isIncoming: isIncoming,
                                  date: date,
                                  channel: channel,
                                  managedContext: self.managedContext)

        try self.save(message)

        return message
    }

    func createMediaMessage(_ data: Data,
                            in channel: Channel? = nil,
                            isIncoming: Bool,
                            date: Date = Date(),
                            type: MessageType) throws -> Message {
        let channel = try channel ?? self.getCurrentChannel()

        let message = try Message(media: data,
                                  type: type,
                                  isIncoming: isIncoming,
                                  date: date,
                                  channel: channel,
                                  managedContext: self.managedContext)

        try self.save(message)

        return message
    }
}
