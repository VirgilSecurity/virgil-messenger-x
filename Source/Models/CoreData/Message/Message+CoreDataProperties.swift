//
//  Message+CoreDataProperties.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/16/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//
//

import Foundation
import CoreData

extension Message {
    @NSManaged public var body: String?
    @NSManaged public var date: Date
    @NSManaged public var isIncoming: Bool
    @NSManaged public var media: Data?
    @NSManaged public var channel: Channel
}
