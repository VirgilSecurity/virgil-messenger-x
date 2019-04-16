//
//  CoreDataHelper+Messages.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation
import UIKit
import CoreData

extension CoreDataHelper {
    func saveMessage(_ message: Message, to channel: Channel) throws {
        let messages = channel.mutableOrderedSetValue(forKey: Keys.message.rawValue)
        messages.add(message)

        Log.debug("Core Data: new message added. Count: \(messages.count)")
        self.appDelegate.saveContext()
    }

    func saveTextMessage(_ body: String, to channel: Channel? = nil, isIncoming: Bool, date: Date = Date()) throws {
        guard let channel = channel ?? self.currentChannel else {
            throw CoreDataHelperError.nilCurrentAccount
        }

        let message = try self.createTextMessage(body, in: channel, isIncoming: isIncoming, date: date)

        try self.saveMessage(message, to: channel)
    }

    func saveMediaMessage(_ data: Data, to channel: Channel? = nil, isIncoming: Bool, date: Date = Date(), type: MessageType) throws {
        guard let channel = channel ?? self.currentChannel else {
            throw CoreDataHelperError.nilCurrentAccount
        }

        let message = try self.createMediaMessage(data, in: channel, isIncoming: isIncoming, date: date, type: type)

        try self.saveMessage(message, to: channel)
    }

    func createTextMessage(_ body: String, in channel: Channel? = nil, isIncoming: Bool, date: Date = Date()) throws -> Message {
        guard let channel = channel ?? self.currentChannel else {
            throw CoreDataHelperError.nilCurrentAccount
        }

        guard let entity = NSEntityDescription.entity(forEntityName: Entities.message.rawValue, in: self.managedContext) else {
            Log.error("Core Data: entity not found: " + Entities.message.rawValue)
            throw NSError()
        }

        let message = Message(entity: entity, insertInto: self.managedContext)

        message.body = body
        message.isIncoming = isIncoming
        message.date = date
        message.type = MessageType.text.rawValue

        channel.lastMessagesBody = body
        channel.lastMessagesDate = date

        return message
    }

    func createMediaMessage(_ data: Data, in channel: Channel? = nil, isIncoming: Bool, date: Date = Date(), type: MessageType) throws -> Message {
        guard let channel = channel ?? self.currentChannel else {
            throw CoreDataHelperError.nilCurrentAccount
        }

        guard let entity = NSEntityDescription.entity(forEntityName: Entities.message.rawValue, in: self.managedContext) else {
            Log.error("Core Data: entity not found: " + Entities.message.rawValue)
            throw NSError()
        }

        let message = Message(entity: entity, insertInto: self.managedContext)

        message.media = data
        message.isIncoming = isIncoming
        message.date = date
        message.type = type.rawValue

        channel.lastMessagesBody = self.lastMessageIdentifier[type.rawValue] ?? ""
        channel.lastMessagesDate = date

        return message
    }

    func setLastMessage(for channel: Channel) {
        if let messages = channel.message,
            let message = messages.lastObject as? Message,
            let date = message.date,
            let rawType = message.type,
            let type = MessageType(rawValue: rawType)
        {
            switch type {
            case .text:
                guard let body = message.body else {
                    Log.error("Missing message body")
                    return
                }

                channel.lastMessagesBody = body
            case .photo, .audio:
                channel.lastMessagesBody = self.lastMessageIdentifier[message.type!] ?? "unknown media message type"
            }

            channel.lastMessagesDate = date
        }
    }
}
