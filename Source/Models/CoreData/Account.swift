//
//  Account+CoreDataClass.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 12/15/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//
//

import CoreData
import VirgilSDK

@objc(Account)
public class Account: NSManagedObject {
    @NSManaged public var identity: String
    
    @NSManaged private var numColorPair: Int32
    @NSManaged private var orderedChannels: NSOrderedSet?

    public static let EntityName = "Account"
    public static let ChannelsKey = "orderedChannels"

    public var channels: [Channel] {
        get {
            return self.orderedChannels?.array as? [Channel] ?? []
        }
    }

    public var colorPair: ColorPair {
        get {
            return UIConstants.colorPairs[Int(self.numColorPair)]
        }
    }

    public var letter: String {
        get {
            return String(describing: self.identity.uppercased().first!)
        }
    }

    convenience init(identity: String, managedContext: NSManagedObjectContext) throws {
        guard let entity = NSEntityDescription.entity(forEntityName: Account.EntityName, in: managedContext) else {
            throw CoreDataHelperError.entityNotFound
        }

        self.init(entity: entity, insertInto: managedContext)

        self.identity = identity
        self.numColorPair = Int32(arc4random_uniform(UInt32(UIConstants.colorPairs.count)))
    }
}