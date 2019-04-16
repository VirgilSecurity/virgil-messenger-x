//
//  Account+CoreDataClass.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 12/15/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Account)
public class Account: NSManagedObject {
    @NSManaged private var numColorPair: Int32
    @NSManaged private var orderedChannels: NSOrderedSet?

    public var channels: [Channel] {
        return self.orderedChannels?.array as? [Channel] ?? []
    }

    public var colorPair: ColorPair {
        get {
            return UIConstants.colorPairs[Int(self.numColorPair)]
        }
    }

    public func setupColorPair() {
        self.numColorPair = Int32(arc4random_uniform(UInt32(UIConstants.colorPairs.count)))
    }

    public var letter: String {
        get {
            return String(describing: self.identity.uppercased().first!)
        }
    }
}
