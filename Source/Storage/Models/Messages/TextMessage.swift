//
//  TextMessage+PersistentStorageClass.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/10/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import CoreData
import ChattoAdditions

extension Storage {
    @objc(TextMessage)
    public class TextMessage: Message {
        @NSManaged public var body: String

        private static let EntityName = "TextMessage"

        convenience init(body: String, baseParams: Message.Params, context: NSManagedObjectContext) throws {
            try self.init(entityName: TextMessage.EntityName, context: context, params: baseParams)

            self.body = body
        }
    }
}
