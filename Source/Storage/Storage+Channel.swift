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

            // TODO: wrap to enum?
            if let textMessage = message as? TextMessage {
                return textMessage.body
            } else if message is PhotoMessage {
                return "Photo"
            } else if message is VoiceMessage {
                return "Voice Message"
            } else if let call = message as? CallMessage {
                return call.isIncoming ? "Incomming call from \(call.channelName)" : "Outgoing call to \(call.channelName)"
            } else {
                return ""
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
            switch self.type {
            case .single, .singleRatchet:
                if let card = self.cards.first {
                    return card
                }
            case .group:
                break
            }

            throw Storage.Error.invalidChannel
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
