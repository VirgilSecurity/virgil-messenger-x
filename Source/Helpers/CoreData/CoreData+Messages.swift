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
        let message = try TextMessage(body: "Message encrypted",
                                      isIncoming: isIncoming,
                                      date: date,
                                      channel: channel,
                                      isHidden: true,
                                      managedContext: self.managedContext)

        try self.save(message)
    }

    func createTextMessage(with content: TextContent,
                           in channel: Channel,
                           isIncoming: Bool,
                           date: Date = Date()) throws -> Message {

        let message = try TextMessage(body: content.body,
                                      isIncoming: isIncoming,
                                      date: date,
                                      channel: channel,
                                      managedContext: self.managedContext)

        try self.save(message)

        return message
    }
    
    func createPhotoMessage(with content: PhotoContent,
                            thumbnail: Data,
                            in channel: Channel,
                            isIncoming: Bool,
                            date: Date = Date()) throws -> Message {
        let message = try PhotoMessage(identifier: content.identifier,
                                       thumbnail: thumbnail,
                                       url: content.url,
                                       isIncoming: isIncoming,
                                       date: date,
                                       channel: channel,
                                       managedContext: self.managedContext)

        try self.save(message)

        return message
    }
    
    func createVoiceMessage(with content: VoiceContent,
                            in channel: Channel,
                            isIncoming: Bool,
                            date: Date = Date()) throws -> Message {
        let message = try VoiceMessage(identifier: content.identifier,
                                       duration: content.duration,
                                       url: content.url,
                                       isIncoming: isIncoming,
                                       date: date,
                                       channel: channel,
                                       managedContext: self.managedContext)

        try self.save(message)

        return message
    }
    
    func storeMediaContent(_ data: Data, name: String) throws {
        try self.getMediaStorage().store(data, name: name)
    }
}
