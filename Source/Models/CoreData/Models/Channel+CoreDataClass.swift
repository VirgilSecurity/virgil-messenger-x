//
//  Channel+CoreDataClass.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 12/15/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Channel)
public class Channel: NSManagedObject {
    var lastMessagesBody: String = ""
    var lastMessagesDate: Date?

    var letter: String {
        get {
            return String(describing: self.name!.uppercased().first!)
        }
    }

    var colorPair: ColorPair {
        get {
            return UIConstants.colorPairs[Int(self.numColorPair)]
        }
    }
}
