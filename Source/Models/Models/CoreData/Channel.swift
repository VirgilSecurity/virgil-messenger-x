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

@objc(Channel)
public class Channel: NSManagedObject {
    @NSManaged public var name: String
    @NSManaged public var account: Account
    @NSManaged public var sessionId: Data?

    @NSManaged private var rawType: String
    @NSManaged private var numColorPair: Int32
    @NSManaged private var orderedMessages: NSOrderedSet?
    @NSManaged private var orderedMembers: NSOrderedSet?
    @NSManaged private var orderedServiceMessages: NSOrderedSet?
    @NSManaged private var rawCards: [String]

    private static let EntityName = "Channel"

    public static let MessagesKey = "orderedMessages"
    public static let MembersKey = "orderedMembers"
    public static let ServiceMessagesKey = "orderedServiceMessages"

    public var messages: [Message] {
        return self.orderedMessages?.array as? [Message] ?? []
    }

    public var members: [User] {
        return self.orderedMembers?.array as? [User] ?? []
    }

    public var serviceMessages: [ServiceMessage] {
        return self.orderedServiceMessages?.array as? [ServiceMessage] ?? []
    }

    public var cards: [Card] {
        get {
            let cards: [Card] = self.rawCards.map {
                try! VirgilHelper.shared.importCard(fromBase64Encoded: $0)
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

    public var colorPair: ColorPair {
        return UIConstants.colorPairs[Int(self.numColorPair)]
    }

    public var lastMessagesBody: String {
        guard let message = self.messages.last else {
            return ""
        }

        switch message.type {
        case .text:
            return message.body ?? ""
        case .photo:
            return "Photo"
        case .audio:
            return "Voice Message"
        }
    }

    public var lastMessagesDate: Date? {
        guard let message = self.messages.last else {
            return nil
        }

        return message.date
    }

    public var letter: String {
        get {
            return String(describing: self.name.uppercased().first!)
        }
    }

    convenience init(name: String,
                     type: ChannelType,
                     account: Account,
                     cards: [Card],
                     sessionId: Data?,
                     managedContext: NSManagedObjectContext) throws {
        guard let entity = NSEntityDescription.entity(forEntityName: Channel.EntityName, in: managedContext) else {
            throw CoreDataHelperError.entityNotFound
        }

        self.init(entity: entity, insertInto: managedContext)

        self.name = name
        self.type = type
        self.cards = cards
        self.sessionId = sessionId
        self.numColorPair = Int32(arc4random_uniform(UInt32(UIConstants.colorPairs.count)))

        let accountChannels = account.mutableOrderedSetValue(forKey: Account.ChannelsKey)
        accountChannels.add(self)
    }
}
