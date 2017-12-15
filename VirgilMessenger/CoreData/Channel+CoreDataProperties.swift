//
//  Channel+CoreDataProperties.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 12/15/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//
//

import Foundation
import CoreData


extension Channel {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Channel> {
        return NSFetchRequest<Channel>(entityName: "Channel")
    }

    @NSManaged public var card: String?
    @NSManaged public var name: String?
    @NSManaged public var numColorPair: Int32
    @NSManaged public var account: Account?
    @NSManaged public var message: NSOrderedSet?

}

// MARK: Generated accessors for message
extension Channel {

    @objc(insertObject:inMessageAtIndex:)
    @NSManaged public func insertIntoMessage(_ value: Message, at idx: Int)

    @objc(removeObjectFromMessageAtIndex:)
    @NSManaged public func removeFromMessage(at idx: Int)

    @objc(insertMessage:atIndexes:)
    @NSManaged public func insertIntoMessage(_ values: [Message], at indexes: NSIndexSet)

    @objc(removeMessageAtIndexes:)
    @NSManaged public func removeFromMessage(at indexes: NSIndexSet)

    @objc(replaceObjectInMessageAtIndex:withObject:)
    @NSManaged public func replaceMessage(at idx: Int, with value: Message)

    @objc(replaceMessageAtIndexes:withMessage:)
    @NSManaged public func replaceMessage(at indexes: NSIndexSet, with values: [Message])

    @objc(addMessageObject:)
    @NSManaged public func addToMessage(_ value: Message)

    @objc(removeMessageObject:)
    @NSManaged public func removeFromMessage(_ value: Message)

    @objc(addMessage:)
    @NSManaged public func addToMessage(_ values: NSOrderedSet)

    @objc(removeMessage:)
    @NSManaged public func removeFromMessage(_ values: NSOrderedSet)

}
