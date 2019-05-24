//
//  CoreDataHelper+Messages.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import CoreData
import VirgilCryptoRatchet
import VirgilSDK

extension CoreDataHelper {
    func save(_ message: Message) throws {
        let messages = message.channel.mutableOrderedSetValue(forKey: Channel.MessagesKey)
        messages.add(message)

        self.appDelegate.saveContext()
    }

    func save(_ message: ServiceMessage, to channel: Channel) throws {
        let messages = channel.mutableOrderedSetValue(forKey: Channel.ServiceMessagesKey)
        messages.add(message)

        self.appDelegate.saveContext()
    }

    func createChangeMembersMessage(_ body: String,
                                    in channel: Channel? = nil,
                                    isIncoming: Bool,
                                    date: Date = Date()) throws -> Message {
        guard let channel = channel ?? self.currentChannel else {
            throw CoreDataHelperError.nilCurrentChannel
        }

        return try Message(body: body,
                           type: .changeMembers,
                           isIncoming: isIncoming,
                           date: date,
                           channel: channel,
                           managedContext: self.managedContext)
    }

    func createTextMessage(_ body: String,
                           in channel: Channel? = nil,
                           isIncoming: Bool,
                           date: Date = Date()) throws -> Message {
        guard let channel = channel ?? self.currentChannel else {
            throw CoreDataHelperError.nilCurrentChannel
        }

        return try Message(body: body,
                           type: .text,
                           isIncoming: isIncoming,
                           date: date,
                           channel: channel,
                           managedContext: self.managedContext)
    }

    func createMediaMessage(_ data: Data,
                            in channel: Channel? = nil,
                            isIncoming: Bool,
                            date: Date = Date(),
                            type: MessageType) throws -> Message {
        guard let channel = channel ?? self.currentChannel else {
            throw CoreDataHelperError.nilCurrentChannel
        }

        return try Message(media: data,
                           type: type,
                           isIncoming: isIncoming,
                           date: date,
                           channel: channel,
                           managedContext: self.managedContext)
    }

    func findServiceMessage(from identity: String, withSessionId sessionId: Data, identifier: String? = nil) throws -> ServiceMessage? {
        guard let user = self.getSingleChannel(with: identity) else {
            throw NSError()
        }

        return user.serviceMessages.first { $0.message.getSessionId() == sessionId && $0.identifier == identifier }
    }

    func existsServiceMessages(from identity: String, withSessionId sessionId: Data) -> Bool {
        guard let user = self.getSingleChannel(with: identity) else {
            return false
        }

        return user.serviceMessages.first { $0.message.getSessionId() == sessionId } != nil
    }

    func delete(_ serviceMessage: ServiceMessage) {
        self.managedContext.delete(serviceMessage)

        self.appDelegate.saveContext()
    }
}