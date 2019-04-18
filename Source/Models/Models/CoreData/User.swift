//
//  User+CoreDataClass.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/18/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//
//

import CoreData
import VirgilSDK

@objc(User)
public class User: NSManagedObject {
    @NSManaged public var identity: String
    @NSManaged private var numColorPair: Int32

    @NSManaged private var orderedChannels: NSOrderedSet?
    @NSManaged private var rawCard: String

    public var channels: [Channel] {
        return self.orderedChannels?.array as? [Channel] ?? []
    }

    public var card: Card {
        get {
            return try! VirgilHelper.shared.importCard(fromBase64Encoded: self.rawCard)
        }

        set {
            self.rawCard = try! newValue.getRawCard().exportAsBase64EncodedString()
        }
    }
}
