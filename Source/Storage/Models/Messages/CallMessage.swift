//
//  Storage+CallMessage.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 12.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import CoreData

extension Storage {
    @objc(CallMessage)
    public class CallMessage: Message {
        @NSManaged public var callUUID: UUID
        @NSManaged public var duration: TimeInterval

        private static let EntityName = "CallMessage"

        convenience init(callUUID: UUID,
                         duration: TimeInterval = 0.0,
                         baseParams: Message.Params,
                         context: NSManagedObjectContext) throws {
            try self.init(entityName: CallMessage.EntityName, context: context, params: baseParams)

            self.callUUID = callUUID
            self.duration = duration
        }
    }
}
