//
//  CoreDataHelper+Messages.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import UIKit
import CoreData

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

//    func saveMediaMessage(_ data: Data, to channel: Channel? = nil, isIncoming: Bool, date: Date = Date(), type: MessageType) throws {
//        guard let channel = channel ?? self.currentChannel else {
//            throw CoreDataHelperError.nilCurrentAccount
//        }
//
//        let message = try self.createMediaMessage(data, in: channel, isIncoming: isIncoming, date: date, type: type)
//
//        try self.saveMessage(message)
//    }
//
    func saveServiceMessage(_ message: Data, to channel: Channel, type: ServiceMessageType) throws {
        let serviceMessage = try self.createServiceMessage(message, type: type)

        let messages = channel.mutableOrderedSetValue(forKey: Channel.ServiceMessagesKey)
        messages.add(serviceMessage)

        Log.debug("Core Data: new service added")
        self.appDelegate.saveContext()
    }

    private func createServiceMessage(_ message: Data, type: ServiceMessageType) throws -> ServiceMessage {
        return try ServiceMessage(message: message,
                                  type: type,
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
}
