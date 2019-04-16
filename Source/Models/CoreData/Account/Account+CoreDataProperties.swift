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
    @NSManaged public var card: String
    @NSManaged public var identity: String
}
