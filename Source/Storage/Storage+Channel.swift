//
//  Storage+Storage.Channel.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import CoreData
import VirgilSDK
import VirgilE3Kit
import CoreGraphics

extension Storage {
    public enum ChannelType: String, Codable {
        case single
        case group
    }

    @objc(Channel)
    public class Channel: NSManagedObject {
        @NSManaged public var sid: String
        @NSManaged public var name: String
        @NSManaged public var account: Storage.Account
        @NSManaged public var createdAt: Date
        @NSManaged public var initiator: String

        @NSManaged private var rawType: String
        @NSManaged private var numColorPair: Int32
        @NSManaged private var orderedMessages: NSOrderedSet?
        @NSManaged private var rawCards: [String]

        private(set) var group: VirgilE3Kit.Group?

        public static let MessagesKey = "orderedMessages"

        private static let EntityName = "Channel"

        public var visibleMessages: [Storage.Message] {
            guard let messages = self.orderedMessages?.array as? [Storage.Message] else {
                return []
            }

            return messages.filter { !$0.isHidden }
        }

        public var allMessages: [Storage.Message] {
            return self.orderedMessages?.array as? [Storage.Message] ?? []
        }

        public var cards: [Card] {
            get {
                let cards: [Card] = self.rawCards.map {
                    try! Virgil.shared.importCard(fromBase64Encoded: $0)
                }

                return cards
            }

            set {
                self.rawCards = newValue.map { try! $0.getRawCard().exportAsBase64EncodedString() }
            }
        }

        public var type: ChannelType {
            get {
                return ChannelType(rawValue: self.rawType) ?? .single
            }

            set {
                self.rawType = newValue.rawValue
            }
        }

        public var colors: [CGColor] {
            let colorPair = UIConstants.colorPairs[Int(self.numColorPair)]

            return [colorPair.first, colorPair.second]
        }

        public var lastMessagesBody: String {
            guard let message = self.visibleMessages.last else {
                return ""
            }

            if let textMessage = message as? TextMessage {
                return textMessage.body
            }
            else {
                // TODO: Hande oher message types.
                return "Unknown message"
            }
        }

        public var lastMessagesDate: Date? {
            guard let message = self.visibleMessages.last else {
                return nil
            }

            return message.date
        }

        public var letter: String {
            get {
                return String(describing: self.name.uppercased().first!)
            }
        }

        convenience init(sid: String,
                         name: String,
                         initiator: String,
                         type: ChannelType,
                         account: Storage.Account,
                         cards: [Card],
                         managedContext: NSManagedObjectContext) throws {
            guard let entity = NSEntityDescription.entity(forEntityName: Storage.Channel.EntityName, in: managedContext) else {
                throw Storage.Error.entityNotFound
            }

            self.init(entity: entity, insertInto: managedContext)

            self.sid = sid
            self.name = name
            self.initiator = initiator
            self.account = account
            self.type = type
            self.cards = cards
            self.createdAt = Date()
            self.numColorPair = Int32(arc4random_uniform(UInt32(UIConstants.colorPairs.count)))
        }

        public func getCard() throws -> Card {
            guard self.type == .single, let card = self.cards.first else {
                throw Storage.Error.invalidChannel
            }

            return card
        }

        public func getGroup() throws -> Group {
            guard self.type == .group, let group = self.group else {
                throw Storage.Error.missingVirgilGroup
            }

            return group
        }

        public func set(group: Group) {
            self.group = group
        }
    }
}

extension Storage {
    private func save(_ channel: Storage.Channel) throws {
        let channels = channel.account.mutableOrderedSetValue(forKey: Storage.Account.ChannelsKey)
        channels.add(channel)

        try self.saveContext()
    }

    func createGroupChannel(name: String, sid: String, initiator: String, cards: [Card]) throws -> Storage.Channel {
        return try self.createChannel(type: .group, sid: sid, name: name, initiator: initiator, cards: cards)
    }

    func createSingleChannel(initiator: String, card: Card) throws -> Storage.Channel {
        // FIXME
        let sid = UUID().uuidString

        guard card.identity != Virgil.ethree.identity else {
            throw UserFriendlyError.createSelfChatForbidded
        }

        if let channel = self.getChannel(withName: card.identifier) {
            return channel
        }

        return try self.createChannel(type: .single, sid: sid, name: card.identity, initiator: initiator, cards: [card])
    }

    private func createChannel(type: Storage.ChannelType, sid: String, name: String, initiator: String, cards: [Card]) throws -> Storage.Channel {
        let cards = cards.filter { $0.identity != Virgil.ethree.identity }
        let account = try self.getCurrentAccount()

        let channel = try Storage.Channel(sid: sid,
                                  name: name,
                                  initiator: initiator,
                                  type: type,
                                  account: account,
                                  cards: cards,
                                  managedContext: self.managedContext)

        try self.save(channel)

        return channel
    }

    func updateCards(with cards: [Card], for channel: Storage.Channel) throws {
        let cards = cards.filter { $0.identity != self.currentAccount?.identity }

        channel.cards = cards

        try self.saveContext()
    }

    func delete(channel: Storage.Channel) throws {
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

    func getChannel(withName name: String) -> Storage.Channel? {
        return self.getChannels().first { $0.name == name }
    }

    func getChannels() -> [Storage.Channel] {
        return self.currentAccount!.channels
    }

    func getSingleChannel(with identity: String) -> Storage.Channel? {
        return self.getSingleChannels().first { $0.name == identity }
    }

    func getSingleChannels() -> [Storage.Channel] {
        return self.getChannels().filter { $0.type == .single }
    }

    func getGroupChannels() -> [Storage.Channel] {
        return self.getChannels().filter { $0.type == .group }
    }

    func getCurrentChannel() throws -> Storage.Channel {
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
}
