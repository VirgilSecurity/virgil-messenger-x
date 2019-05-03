//
//  ServiceMessage+CoreDataClass.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/19/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//
//

import Foundation
import CoreData
import VirgilCryptoRatchet

@objc(ServiceMessage)
public class ServiceMessage: NSManagedObject {
    @NSManaged public var rawMessage: Data
    @NSManaged public var channel: Channel?

    @NSManaged private var rawType: String

    private static let EntityName = "ServiceMessage"

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

    convenience init(message: RatchetGroupMessage, type: ServiceMessageType, managedContext: NSManagedObjectContext) throws {
        guard let entity = NSEntityDescription.entity(forEntityName: ServiceMessage.EntityName,
                                                      in: managedContext) else {
            throw CoreDataHelperError.entityNotFound
        }

        self.init(entity: entity, insertInto: managedContext)

        self.message = message
        self.type = type
    }
}
