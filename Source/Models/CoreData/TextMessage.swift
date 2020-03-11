//
//  TextMessage+CoreDataClass.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/10/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//
//

import Foundation
import CoreData

@objc(TextMessage)
public class TextMessage: Message {
    @NSManaged public var body: String

    private static let EntityName = "TextMessage"
    
    convenience init(body: String,
                     isIncoming: Bool,
                     date: Date,
                     channel: Channel,
                     isHidden: Bool = false,
                     managedContext: NSManagedObjectContext) throws {
        guard let entity = NSEntityDescription.entity(forEntityName: TextMessage.EntityName, in: managedContext) else {
            throw CoreData.Error.entityNotFound
        }

        self.init(entity: entity, insertInto: managedContext)

        self.body = body
        self.isIncoming = isIncoming
        self.date = date
        self.channel = channel
        self.isHidden = isHidden
    }
}
