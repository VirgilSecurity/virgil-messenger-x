//
//  CoreData+Channel.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import CoreData
import VirgilSDK
import UIKit

extension Storage {
    private func save(_ channel: Channel) throws {
        let channels = channel.account.mutableOrderedSetValue(forKey: Account.ChannelsKey)
        channels.add(channel)

        try self.saveContext()
    }

    func createSingleChannel(initiator: String, card: Card) throws -> Channel {
        // TODO: remove sid on channel migration
        let sid = UUID().uuidString

        guard card.identity != Virgil.ethree.identity else {
            throw UserFriendlyError.createSelfChatForbidded
        }

        if let channel = self.getChannel(withName: card.identifier) {
            return channel
        }

        return try self.createChannel(type: .single, sid: sid, name: card.identity, initiator: initiator, cards: [card])
    }

    func createSingleRatchetChannel(initiator: String, card: Card) throws -> Channel {
        // TODO: remove sid on channel migration
        let sid = UUID().uuidString

        guard card.identity != Virgil.ethree.identity else {
            throw UserFriendlyError.createSelfChatForbidded
        }

        if let channel = self.getChannel(withName: card.identifier) {
            return channel
        }

        return try self.createChannel(type: .singleRatchet, sid: sid, name: card.identity, initiator: initiator, cards: [card])
    }

    private func createChannel(type: ChannelType, sid: String, name: String, initiator: String, cards: [Card]) throws -> Channel {
        let cards = cards.filter { $0.identity != Virgil.ethree.identity }
        let account = try self.getCurrentAccount()

        let channel = try Channel(sid: sid,
                                  name: name,
                                  initiator: initiator,
                                  type: type,
                                  account: account,
                                  cards: cards,
                                  managedContext: self.managedContext)

        try self.save(channel)

        return channel
    }

    func updateCards(with cards: [Card], for channel: Channel) throws {
        let cards = cards.filter { $0.identity != self.currentAccount?.identity }

        channel.cards = cards

        try self.saveContext()
    }

    func delete(channel: Channel) throws {
        channel.allMessages.forEach { self.managedContext.delete($0) }

        self.managedContext.delete(channel)

        try self.saveContext()
    }

    func existsSingleChannel(with identity: String) -> Bool {
        return self.getSingleChannels().contains { $0.name == identity }
    }

    func existsChannel(sid: String) -> Bool {
        return self.getChannels().contains { $0.sid == sid }
    }

    func getChannel(withName name: String) -> Channel? {
        return self.getChannels().first { $0.name == name }
    }

    func getChannels() -> [Channel] {
        return self.currentAccount!.channels
    }

    func getSingleChannel(with identity: String) -> Channel? {
        return self.getSingleChannels().first { $0.name == identity }
    }

    func getSingleChannels() -> [Channel] {
        return self.getChannels().filter { ($0.type == .single) || ($0.type == .singleRatchet) }
    }

    func getCurrentChannel() throws -> Channel {
        guard let channel = self.currentChannel else {
            throw Error.nilCurrentChannel
        }

        return channel
    }

    func getSingleChannelsCards(users: [String]) throws -> [Card] {
        let cards: [Card] = try users.map {
            guard let channel = self.getSingleChannel(with: $0) else {
                throw Error.channelNotFound
            }

            guard let card = channel.cards.first else {
                throw Error.invalidChannel
            }

            return card
        }

        return cards
    }

    func resetUnreadCount(for channel: Channel) throws {
        channel.unreadCount = 0

        try self.saveContext()
    }

    func changeChannel(_ channel: Channel, type: ChannelType) throws {
        channel.type = type

        try self.saveContext()
    }
}
