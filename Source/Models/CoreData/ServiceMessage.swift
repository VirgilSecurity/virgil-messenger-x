//
//  ServiceMessage+CoreDataClass.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/19/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//
//

import CoreData
import VirgilCryptoRatchet
import VirgilSDK

@objc(ServiceMessage)
public final class ServiceMessage: NSManagedObject, Codable {
    @NSManaged public var identifier: String?
    @NSManaged public var rawMessage: Data
    @NSManaged public var channel: Channel?

    @NSManaged private var rawType: String
    @NSManaged private var rawCards: [String]
    @NSManaged private var rawCardsAdd: [String]
    @NSManaged private var rawCardsRemove: [String]

    private static let EntityName = "ServiceMessage"

    enum CodingKeys: String, CodingKey {
        case identifier
        case rawMessage
        case rawType
        case rawCards
        case rawCardsAdd
        case rawCardsRemove
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.identifier, forKey: .identifier)
        try container.encode(self.rawMessage, forKey: .rawMessage)
        try container.encode(self.rawType, forKey: .rawType)
        try container.encode(self.rawCards, forKey: .rawCards)
        try container.encode(self.rawCardsAdd, forKey: .rawCardsAdd)
        try container.encode(self.rawCardsRemove, forKey: .rawCardsRemove)
    }

    public var message: RatchetGroupMessage {
        get {
            return try! RatchetGroupMessage.deserialize(input: self.rawMessage)
        }

        set {
            self.rawMessage = newValue.serialize()
        }
    }

    public var type: ServiceMessageType {
        get {
            return ServiceMessageType(rawValue: self.rawType) ?? .newSession
        }

        set {
            self.rawType = newValue.rawValue
        }
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

    public var cardsAdd: [Card] {
        get {
            let cards: [Card] = self.rawCardsAdd.map {
                try! VirgilHelper.shared.importCard(fromBase64Encoded: $0)
            }

            return cards
        }

        set {
            self.rawCardsAdd = newValue.map { try! $0.getRawCard().exportAsBase64EncodedString() }
        }
    }

    public var cardsRemove: [Card] {
        get {
            let cards: [Card] = self.rawCardsRemove.map {
                try! VirgilHelper.shared.importCard(fromBase64Encoded: $0)
            }

            return cards
        }

        set {
            self.rawCardsRemove = newValue.map { try! $0.getRawCard().exportAsBase64EncodedString() }
        }
    }

    convenience init(identifier: String?,
                     message: RatchetGroupMessage,
                     type: ServiceMessageType,
                     members: [Card],
                     add: [Card] = [],
                     remove: [Card] = [],
                     managedContext: NSManagedObjectContext = CoreDataHelper.shared.managedContext) throws {
        guard let entity = NSEntityDescription.entity(forEntityName: ServiceMessage.EntityName,
                                                      in: managedContext) else {
            throw CoreDataHelperError.entityNotFound
        }

        self.init(entity: entity, insertInto: managedContext)

        self.identifier = identifier
        self.message = message
        self.type = type
        self.cards = members
        self.cardsAdd = add
        self.cardsRemove = remove
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let managedContext = CoreDataHelper.shared.managedContext

        guard let entity = NSEntityDescription.entity(forEntityName: ServiceMessage.EntityName,
                                                      in: managedContext) else {
            throw CoreDataHelperError.entityNotFound
        }

        self.init(entity: entity, insertInto: managedContext)

        self.identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
        self.rawMessage = try container.decode(Data.self, forKey: .rawMessage)
        self.rawType = try container.decode(String.self, forKey: .rawType)
        self.rawCards = try container.decode([String].self, forKey: .rawCards)
        self.rawCardsAdd = try container.decode([String].self, forKey: .rawCardsAdd)
        self.rawCardsRemove = try container.decode([String].self, forKey: .rawCardsRemove)
    }
}

extension ServiceMessage {
    static func `import`(_ base64EncodedString: String) throws -> ServiceMessage {
        guard let data = Data(base64Encoded: base64EncodedString) else {
            throw CoreDataHelperError.invalidMessage
        }

        return try JSONDecoder().decode(ServiceMessage.self, from: data)
    }

    func export() throws -> String {
        return try JSONEncoder().encode(self).base64EncodedString()
    }
}

extension ServiceMessage {
    public func getChangeMembersText() throws -> String {
        guard self.type == .changeMembers else {
            throw NSError()
        }

        if self.cardsAdd.isEmpty && self.cardsRemove.isEmpty {
            throw NSError()
        }

        let action = self.cardsAdd.isEmpty ? "removed" : "added"

        let executors = self.cardsAdd.isEmpty ? self.cardsRemove.map { $0.identity } : self.cardsAdd.map { $0.identity }

        return "\(action) \(executors.joined(separator: ", "))"
    }
}
