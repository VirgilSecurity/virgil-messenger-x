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
    var letter: String {
        get {
            return String(describing: self.identity!.uppercased().first!)
        }
    }
    var colorPair: ColorPair {
        get {
            return UIConstants.colorPairs[Int(self.numColorPair)]
        }
    }
}
