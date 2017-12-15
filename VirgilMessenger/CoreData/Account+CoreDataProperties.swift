//
//  Account+CoreDataProperties.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 12/15/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//
//

import Foundation
import CoreData


extension Account {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Account> {
        return NSFetchRequest<Account>(entityName: "Account")
    }

    @NSManaged public var card: String?
    @NSManaged public var identity: String?
    @NSManaged public var numColorPair: Int32
    @NSManaged public var channel: NSOrderedSet?

}

// MARK: Generated accessors for channel
extension Account {

    @objc(insertObject:inChannelAtIndex:)
    @NSManaged public func insertIntoChannel(_ value: Channel, at idx: Int)

    @objc(removeObjectFromChannelAtIndex:)
    @NSManaged public func removeFromChannel(at idx: Int)

    @objc(insertChannel:atIndexes:)
    @NSManaged public func insertIntoChannel(_ values: [Channel], at indexes: NSIndexSet)

    @objc(removeChannelAtIndexes:)
    @NSManaged public func removeFromChannel(at indexes: NSIndexSet)

    @objc(replaceObjectInChannelAtIndex:withObject:)
    @NSManaged public func replaceChannel(at idx: Int, with value: Channel)

    @objc(replaceChannelAtIndexes:withChannel:)
    @NSManaged public func replaceChannel(at indexes: NSIndexSet, with values: [Channel])

    @objc(addChannelObject:)
    @NSManaged public func addToChannel(_ value: Channel)

    @objc(removeChannelObject:)
    @NSManaged public func removeFromChannel(_ value: Channel)

    @objc(addChannel:)
    @NSManaged public func addToChannel(_ values: NSOrderedSet)

    @objc(removeChannel:)
    @NSManaged public func removeFromChannel(_ values: NSOrderedSet)

}
