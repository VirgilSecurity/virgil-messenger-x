//
//  Message+CoreDataClass.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/16/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Message)
public class Message: NSManagedObject {
    @NSManaged private var rawType: String

    public var type: MessageType {
        get {
            return MessageType(rawValue: self.rawType) ?? .text
        }

        set {
            self.rawType = newValue.rawValue
        }
    }
}
