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
                         xmppId: String,
                         isIncoming: Bool,
                         date: Date,
                         channel: Channel,
                         isHidden: Bool = false,
                         managedContext: NSManagedObjectContext) throws {
            guard let entity = NSEntityDescription.entity(forEntityName: VoiceMessage.EntityName,
                                                          in: managedContext) else {
                throw Storage.Error.entityNotFound
            }

            self.init(entity: entity, insertInto: managedContext)

            self.identifier = identifier
            self.duration = duration
            self.url = url
            self.xmppId = xmppId
            self.isIncoming = isIncoming
            self.date = date
            self.channel = channel
            self.isHidden = isHidden
        }
    }
}
