//
//  CoreData+Messages.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import CoreData
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
        let params = Message.Params(xmppId: UUID().uuidString,
                                    isIncoming: isIncoming,
                                    channel: channel,
                                    state: .failed,
                                    date: date,
                                    isHidden: true)

        let message = try TextMessage(body: "Message encrypted",
                                      baseParams: params,
                                      context: self.managedContext)

        try self.save(message, unread: false)
    }

    @discardableResult
    func createTextMessage(with text: NetworkMessage.Text,
                           unread: Bool = false,
                           baseParams: Message.Params) throws -> Message {
        let message = try Storage.TextMessage(body: text.body,
                                              baseParams: baseParams,
                                              context: self.managedContext)

        try self.save(message, unread: unread)

        return message
    }

    @discardableResult
    func createPhotoMessage(with photo: NetworkMessage.Photo,
                            thumbnail: Data,
                            unread: Bool = false,
                            baseParams: Message.Params) throws -> Message {
        let message = try Storage.PhotoMessage(identifier: photo.identifier,
                                               thumbnail: thumbnail,
                                               url: photo.url,
                                               baseParams: baseParams,
                                               context: self.managedContext)

        try self.save(message, unread: unread)

        return message
    }

    @discardableResult
    func createVoiceMessage(with voice: NetworkMessage.Voice,
                            unread: Bool = false,
                            baseParams: Message.Params) throws -> Message {
        let message = try Storage.VoiceMessage(identifier: voice.identifier,
                                               duration: voice.duration,
                                               url: voice.url,
                                               baseParams: baseParams,
                                               context: self.managedContext)

        try self.save(message, unread: unread)

        return message
    }

    @discardableResult
    func createCallMessage(with callOffer: NetworkMessage.CallOffer,
                           unread: Bool = false,
                           baseParams: Message.Params) throws -> Message {

        let message = try Storage.CallMessage(callUUID: callOffer.callUUID,
                                              baseParams: baseParams,
                                              context: self.managedContext)

        try self.save(message, unread: unread)

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
