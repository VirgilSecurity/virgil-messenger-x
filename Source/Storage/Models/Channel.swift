//
//  Storage+Channel.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import CoreData
import VirgilSDK
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
        @NSManaged public var account: Account
        @NSManaged public var createdAt: Date
        @NSManaged public var initiator: String
        @NSManaged public var unreadCount: Int16

        @NSManaged private var rawType: String
        @NSManaged private var numColorPair: Int32
        @NSManaged private var orderedMessages: NSOrderedSet?
        @NSManaged private var rawCards: [String]

        public static let MessagesKey = "orderedMessages"

        private static let EntityName = "Channel"

        public var visibleMessages: [Message] {
            guard let messages = self.orderedMessages?.array as? [Message] else {
                return []
            }

            return messages.filter { !$0.isHidden }
        }

        public var allMessages: [Message] {
            return self.orderedMessages?.array as? [Message] ?? []
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

            switch message {
            case let textMessage as TextMessage:
                return textMessage.body

            case is PhotoMessage:
                return "Photo"

            case is VoiceMessage:
                return "Voice Message"

            case let callMessage as CallMessage:
                return callMessage.isIncoming ? "Incomming call" : "Outgoing call"

            default:
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
                         account: Account,
                         cards: [Card],
                         managedContext: NSManagedObjectContext) throws {
            guard let entity = NSEntityDescription.entity(forEntityName: Channel.EntityName, in: managedContext) else {
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
            self.unreadCount = 0
            self.numColorPair = Int32(arc4random_uniform(UInt32(UIConstants.colorPairs.count)))
        }

        public func getCard() throws -> Card {
            guard self.type == .single, let card = self.cards.first else {
                throw Storage.Error.invalidChannel
            }

            return card
        }

        public func containsCallMessage(with callUUID: UUID) -> Bool {
            return self.allMessages.contains {
                guard let callMessage = $0 as? CallMessage else {
                    return false
                }

                return callMessage.callUUID == callUUID
            }
        }
    }
}
