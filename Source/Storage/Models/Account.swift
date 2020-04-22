//
//  Storage+Account.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import CoreData
import VirgilSDK
import CoreGraphics

/// Model
extension Storage {
    @objc(Account)
    public class Account: NSManagedObject {
        @NSManaged public var identity: String
        @NSManaged public var sendReadReceipts: Bool

        @NSManaged private var numColorPair: Int32
        @NSManaged private var orderedChannels: NSOrderedSet?

        public static let EntityName = "Account"
        public static let ChannelsKey = "orderedChannels"

        public var channels: [Channel] {
            get {
                return self.orderedChannels?.array as? [Channel] ?? []
            }
        }

        public var colors: [CGColor] {
            let colorPair = UIConstants.colorPairs[Int(self.numColorPair)]

            return [colorPair.first, colorPair.second]
        }

        public var letter: String {
            get {
                return String(describing: self.identity.uppercased().first!)
            }
        }

        convenience init(identity: String, managedContext: NSManagedObjectContext) throws {
            guard let entity = NSEntityDescription.entity(forEntityName: Account.EntityName, in: managedContext) else {
                throw Storage.Error.entityNotFound
            }

            self.init(entity: entity, insertInto: managedContext)

            self.identity = identity
            self.numColorPair = Int32(arc4random_uniform(UInt32(UIConstants.colorPairs.count)))
        }

        func totalUnreadCount() -> Int {
            // FIXME: in swift 5.2
            // let totalUnreadCount = self.channels.map(\.unreadCount).reduce(0, +)

            var totalUnreadCount: Int16 = 0
            self.channels.forEach {
                totalUnreadCount += $0.unreadCount
            }

            return Int(totalUnreadCount)
        }
    }
}
