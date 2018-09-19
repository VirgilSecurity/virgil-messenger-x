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

    enum MessageType: String {
        case text
        case photo
        case audio
    }

    func createTextMessage(withBody body: String, isIncoming: Bool, date: Date) {
        guard let channel = self.currentChannel else {
            Log.error("Core Data: missing selected channel")
            return
        }
        channel.lastMessagesBody = body
        channel.lastMessagesDate = date

        self.createTextMessage(for: channel, withBody: body, isIncoming: isIncoming, date: date)
    }

    func createMediaMessage(with data: Data, isIncoming: Bool, date: Date, type: MessageType) {
        guard let channel = self.currentChannel else {
            Log.error("Core Data: nil selected channel")
            return
        }
        channel.lastMessagesBody = self.lastMessageIdentifier[type.rawValue] ?? "unknown media message"
        channel.lastMessagesDate = date

        self.createMediaMessage(for: channel, with: data, isIncoming: isIncoming, date: date, type: type)
    }

    func createTextMessage(for channel: Channel, withBody body: String, isIncoming: Bool, date: Date) {
        guard let entity = NSEntityDescription.entity(forEntityName: Entities.message.rawValue, in: self.managedContext) else {
            Log.error("Core Data: entity not found: " + Entities.message.rawValue)
            return
        }

        let message = Message(entity: entity, insertInto: self.managedContext)

        message.body = body
        message.isIncoming = isIncoming
        message.date = date
        message.type = MessageType.text.rawValue

        let messages = channel.mutableOrderedSetValue(forKey: Keys.message.rawValue)
        messages.add(message)

        Log.debug("Core Data: new message added. Count: \(messages.count)")
        self.appDelegate.saveContext()
    }

    func createMediaMessage(for channel: Channel, with data: Data, isIncoming: Bool, date: Date, type: MessageType) {
        guard let entity = NSEntityDescription.entity(forEntityName: Entities.message.rawValue, in: self.managedContext) else {
            Log.error("Core Data: entity not found: " + Entities.message.rawValue)
            return
        }

        let message = Message(entity: entity, insertInto: self.managedContext)

        message.media = data
        message.isIncoming = isIncoming
        message.date = date
        message.type = type.rawValue

        let messages = channel.mutableOrderedSetValue(forKey: Keys.message.rawValue)
        messages.add(message)

        Log.debug("Core Data: new message added. Count: \(messages.count)")
        self.appDelegate.saveContext()
    }


    func setLastMessage(for channel: Channel) {
        if let messages = channel.message,
            let message = messages.lastObject as? Message,
            let date = message.date {

            switch message.type {
            case MessageType.text.rawValue:
                guard let body = message.body else {
                    Log.error("Missing message body")
                    return
                }
                channel.lastMessagesBody = body
            case MessageType.photo.rawValue, MessageType.audio.rawValue:
                channel.lastMessagesBody = self.lastMessageIdentifier[message.type!] ?? "unknown media message type"
            default:
                Log.error("Unknown message type")
            }
            channel.lastMessagesDate = date
        }
    }
}
