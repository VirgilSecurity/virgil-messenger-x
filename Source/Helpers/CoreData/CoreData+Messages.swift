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
                           in channel: Channel,
                           isIncoming: Bool,
                           date: Date = Date()) throws -> Message {
        let message = try Message(body: body,
                                  type: .text,
                                  isIncoming: isIncoming,
                                  date: date,
                                  channel: channel,
                                  managedContext: self.managedContext)

        try self.save(message)

        return message
    }
    
    func createMediaMessage(type: MessageType,
                            in channel: Channel,
                            mediaHash: String,
                            mediaUrl: URL,
                            isIncoming: Bool,
                            date: Date = Date()) throws -> Message {
        guard type != .text else {
            throw NSError()
        }

        let message = try Message(body: nil,
                                  type: .photo,
                                  isIncoming: isIncoming,
                                  date: date,
                                  channel: channel,
                                  mediaHash: mediaHash,
                                  mediaUrl: mediaUrl,
                                  managedContext: self.managedContext)

        try self.save(message)

        return message
    }
    
    func storeMediaContent(_ data: Data, name: String) throws {
        try self.getMediaStorage().store(data, name: name)
    }
    
//    func retrieveMediaContent(name: String) throws -> Data {
//        return try self.getMediaStorage().retrieve(name: name)
//    }
}
