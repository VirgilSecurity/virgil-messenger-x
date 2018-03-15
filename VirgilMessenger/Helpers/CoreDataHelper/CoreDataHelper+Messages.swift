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
    func createTextMessage(withBody body: String, isIncoming: Bool, date: Date) {
        guard let channel = self.currentChannel else {
            Log.error("Core Data: nil selected channel")
            return
        }
        channel.lastMessagesBody = body
        channel.lastMessagesDate = date

        self.createTextMessage(forChannel: channel, withBody: body, isIncoming: isIncoming, date: date)
    }

    func createMediaMessage(withData data: Data, isIncoming: Bool, date: Date) {
        guard let channel = self.currentChannel else {
            Log.error("Core Data: nil selected channel")
            return
        }
        channel.lastMessagesBody = "image.jpg"
        channel.lastMessagesDate = date

        self.createMediaMessage(forChannel: channel, withData: data, isIncoming: isIncoming, date: date)
    }

    func createTextMessage(forChannel channel: Channel, withBody body: String, isIncoming: Bool, date: Date) {
        self.queue.async {
            guard let entity = NSEntityDescription.entity(forEntityName: Entities.message.rawValue, in: self.managedContext) else {
                Log.error("Core Data: entity not found: " + Entities.message.rawValue)
                return
            }

            let message = Message(entity: entity, insertInto: self.managedContext)

            let encryptedBody = try? VirgilHelper.sharedInstance.encrypt(text: body)
            message.body = encryptedBody ?? "Error encrypting message"
            message.isIncoming = isIncoming
            message.date = date

            let messages = channel.mutableOrderedSetValue(forKey: Keys.message.rawValue)
            messages.add(message)

            Log.debug("Core Data: new message added. Count: \(messages.count)")
            self.appDelegate.saveContext()
        }
    }

    func createMediaMessage(forChannel channel: Channel, withData data: Data, isIncoming: Bool, date: Date) {
        self.queue.async {
            guard let entity = NSEntityDescription.entity(forEntityName: Entities.message.rawValue, in: self.managedContext) else {
                Log.error("Core Data: entity not found: " + Entities.message.rawValue)
                return
            }

            let message = Message(entity: entity, insertInto: self.managedContext)

            guard let encryptedMedia = try? VirgilHelper.sharedInstance.encrypt(data: data) else {
                Log.error("Encryption media failed")
                return
            }
            message.media = encryptedMedia
            message.isIncoming = isIncoming
            message.date = date

            let messages = channel.mutableOrderedSetValue(forKey: Keys.message.rawValue)
            messages.add(message)

            Log.debug("Core Data: new message added. Count: \(messages.count)")
            self.appDelegate.saveContext()
        }
    }


    func setLastMessage(for channel: Channel) {
        if let messages = channel.message,
            let message = messages.lastObject as? Message,
            let date = message.date {

            if message.media != nil {
                channel.lastMessagesBody = "image.jpg"
            } else if let messageBody = message.body {
                guard let decryptedMessageBody = try? VirgilHelper.sharedInstance.decrypt(text: messageBody) else {
                    Log.error("Core Data: decrypting last message failed")
                    return
                }
                channel.lastMessagesBody = decryptedMessageBody
            }
            channel.lastMessagesDate = date
        }
    }
}
