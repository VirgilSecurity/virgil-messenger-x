//
//  Storage+Message.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import CoreData
import VirgilCryptoRatchet
import VirgilSDK

extension Storage {
    @objc(Message)
    public class Message: NSManagedObject {
        @NSManaged public var xmppId: String
        @NSManaged public var date: Date
        @NSManaged public var isIncoming: Bool
        @NSManaged public var channel: Storage.Channel
        @NSManaged public var isHidden: Bool
    }
}
