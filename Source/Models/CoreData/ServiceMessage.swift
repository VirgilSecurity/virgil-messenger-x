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
    @NSManaged public var rawMessage: Data
    @NSManaged public var channel: Channel?
    @NSManaged public var members: [String]
    @NSManaged public var add: [String]
    @NSManaged public var remove: [String]

    private static let EntityName = "ServiceMessage"

    enum CodingKeys: String, CodingKey {
        case identifier
        case rawMessage
        case members
        case add
        case remove
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.rawMessage, forKey: .rawMessage)
        try container.encode(self.members, forKey: .members)
        try container.encode(self.add, forKey: .add)
        try container.encode(self.remove, forKey: .remove)
    }

    public var message: RatchetGroupMessage {
        get {
            return try! RatchetGroupMessage.deserialize(input: self.rawMessage)
        }

        set {
            self.rawMessage = newValue.serialize()
        }
    }

    public var identifier: String? {
        var epoch = self.message.getEpoch()

        guard epoch != 0 else {
            return nil
        }
        
        let sessionId = self.message.getSessionId()
        let epochData = Data(bytes: &epoch, count: MemoryLayout.size(ofValue: epoch))

        let identifier = sessionId + epochData

        return identifier.base64EncodedString()
    }

    convenience init(message: RatchetGroupMessage,
                     members: [String],
                     add: [String] = [],
                     remove: [String] = [],
                     managedContext: NSManagedObjectContext = CoreData.shared.managedContext) throws {
        guard let entity = NSEntityDescription.entity(forEntityName: ServiceMessage.EntityName,
                                                      in: managedContext) else {
            throw CoreData.Error.entityNotFound
        }

        self.init(entity: entity, insertInto: managedContext)

        self.message = message
        self.members = members
        self.add = add
        self.remove = remove
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let managedContext = CoreData.shared.managedContext

        guard let entity = NSEntityDescription.entity(forEntityName: ServiceMessage.EntityName,
                                                      in: managedContext) else {
            throw CoreData.Error.entityNotFound
        }

        self.init(entity: entity, insertInto: managedContext)

        self.rawMessage = try container.decode(Data.self, forKey: .rawMessage)
        self.members = try container.decode([String].self, forKey: .members)
        self.add = try container.decode([String].self, forKey: .add)
        self.remove = try container.decode([String].self, forKey: .remove)
    }
}

extension ServiceMessage {
    static func `import`(_ base64EncodedString: String) throws -> ServiceMessage {
        guard let data = Data(base64Encoded: base64EncodedString) else {
            throw CoreData.Error.invalidMessage
        }

        return try JSONDecoder().decode(ServiceMessage.self, from: data)
    }

    func export() throws -> String {
        return try JSONEncoder().encode(self).base64EncodedString()
    }
}

extension ServiceMessage {
    public func getChangeMembersText() throws -> String {
        if self.add.isEmpty && self.remove.isEmpty {
            throw CoreData.Error.invalidMessage
        }

        let action = self.add.isEmpty ? "removed" : "added"

        let executors = self.add.isEmpty ? self.remove : self.add

        return "\(action) \(executors.joined(separator: ", "))"
    }
}
