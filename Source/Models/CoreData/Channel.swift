//
//  Channel+CoreDataClass.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 12/15/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//
//

import CoreData
import VirgilSDK
import UIKit
import VirgilE3Kit

@objc(Channel)
public class Channel: NSManagedObject {
    @NSManaged public var sid: String
    @NSManaged public var name: String
    @NSManaged public var account: Account
    @NSManaged public var createdAt: Date
    @NSManaged public var initiator: String

    @NSManaged private var rawType: String
    @NSManaged private var numColorPair: Int32
    @NSManaged private var orderedMessages: NSOrderedSet?
    @NSManaged private var orderedServiceMessages: NSOrderedSet?
    @NSManaged private var rawCards: [String]

    private(set) var group: Group?

    public static let MessagesKey = "orderedMessages"
    public static let MembersKey = "orderedMembers"
    public static let ServiceMessagesKey = "orderedServiceMessages"

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

        switch message.type {
        case .text, .changeMembers:
            return message.body ?? ""
        case .photo:
            return "Photo"
        case .audio:
            return "Voice Message"
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
            throw CoreData.Error.entityNotFound
        }

        self.init(entity: entity, insertInto: managedContext)

        self.sid = sid
        self.name = name
        self.initiator = initiator
        self.type = type
        self.cards = cards
        self.createdAt = Date()
        self.numColorPair = Int32(arc4random_uniform(UInt32(UIConstants.colorPairs.count)))

        let accountChannels = account.mutableOrderedSetValue(forKey: Account.ChannelsKey)
        accountChannels.add(self)
    }

    public func getCard() throws -> Card {
        guard self.type == .single, let card = self.cards.first else {
            throw CoreData.Error.invalidChannel
        }

        return card
    }

    public func getGroup() throws -> Group {
        guard self.type == .group, let group = self.group else {
            throw NSError()
        }

        return group
    }

    public func set(group: Group) {
        self.group = group
    }
}
