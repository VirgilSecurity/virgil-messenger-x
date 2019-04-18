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
    @NSManaged public var name: String
    @NSManaged public var account: Account
}
