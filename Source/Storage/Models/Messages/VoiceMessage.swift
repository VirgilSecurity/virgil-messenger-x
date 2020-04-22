//
//  Strage+VoiceMessage.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/16/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//
//

import Foundation
import CoreData
import ChattoAdditions

extension Storage {
    @objc(VoiceMessage)
    public class VoiceMessage: Message {
        @NSManaged public var identifier: String
        @NSManaged public var url: URL
        @NSManaged public var duration: Double

        private static let EntityName = "VoiceMessage"

        convenience init(identifier: String,
                         duration: Double,
                         url: URL,
                         baseParams: Message.Params,
                         context: NSManagedObjectContext) throws {
            try self.init(entityName: VoiceMessage.EntityName, context: context, params: baseParams)

            self.identifier = identifier
            self.duration = duration
            self.url = url
        }
    }
}
