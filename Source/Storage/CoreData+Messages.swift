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

extension Storage {
    private func save(_ message: Message, unread: Bool) throws {
        if unread {
            message.channel.unreadCount += 1
        }

        let messages = message.channel.mutableOrderedSetValue(forKey: Channel.MessagesKey)
        messages.add(message)

        try self.saveContext()
    }

    func createEncryptedMessage(in channel: Storage.Channel, isIncoming: Bool, date: Date) throws {
        let message = try TextMessage(body: "Message encrypted",
                                      xmppId: UUID().uuidString,
                                      isIncoming: isIncoming,
                                      date: date,
                                      channel: channel,
                                      isHidden: true,
                                      managedContext: self.managedContext)

        try self.save(message, unread: false)
    }

    func createTextMessage(_ content: NetworkMessage.Text,
                           unread: Bool = false,
                           xmppId: String,
                           in channel: Storage.Channel,
                           isIncoming: Bool,
                           date: Date = Date()) throws -> Message {

        let message = try TextMessage(body: content.body,
                                      xmppId: xmppId,
                                      isIncoming: isIncoming,
                                      date: date,
                                      channel: channel,
                                      managedContext: self.managedContext)

        try self.save(message, unread: unread)

        return message
    }

    func createPhotoMessage(_ content: NetworkMessage.Photo,
                            thumbnail: Data,
                            unread: Bool = false,
                            xmppId: String,
                            in channel: Storage.Channel,
                            isIncoming: Bool,
                            date: Date = Date()) throws -> Message {

        let message = try PhotoMessage(identifier: content.identifier,
                                       thumbnail: thumbnail,
                                       url: content.url,
                                       xmppId: xmppId,
                                       isIncoming: isIncoming,
                                       date: date,
                                       channel: channel,
                                       managedContext: self.managedContext)

        try self.save(message, unread: unread)

        return message
    }

    func createVoiceMessage(_ content: NetworkMessage.Voice,
                            unread: Bool = false,
                            xmppId: String,
                            in channel: Storage.Channel,
                            isIncoming: Bool,
                            date: Date = Date()) throws -> Message {

        let message = try VoiceMessage(identifier: content.identifier,
                                       duration: content.duration,
                                       url: content.url,
                                       xmppId: xmppId,
                                       isIncoming: isIncoming,
                                       date: date,
                                       channel: channel,
                                       managedContext: self.managedContext)

        try self.save(message, unread: unread)

        return message
    }

    func createCallMessage(xmppId: String,
                           in channel: Storage.Channel,
                           isIncoming: Bool,
                           date: Date = Date()) throws -> Storage.Message {

        let message = try Storage.CallMessage(xmppId: xmppId,
                                              isIncoming: isIncoming,
                                              date: date,
                                              channel: channel,
                                      managedContext: self.managedContext)

        try self.save(message, unread: false)

        return message
    }

    func storeMediaContent(_ data: Data, name: String, type: FileMediaStorage.MediaType) throws {
        let mediaStorage = try self.getMediaStorage()

        let path = try mediaStorage.getPath(name: name, type: type)

        if type == .photo, mediaStorage.exists(path: path) {
            return
        }

        try self.getMediaStorage().store(data, name: name, type: type)
    }
}
