//
//  VoiceMessage.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/16/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//
//

import Foundation
import CoreData
import ChattoAdditions

@objc(VoiceMessage)
public class VoiceMessage: Message {
    @NSManaged public var identifier: String
    @NSManaged public var url: URL
    @NSManaged public var duration: Int
    
    private static let EntityName = "VoiceMessage"
    
    convenience init(identifier: String,
                     duration: Int,
                     url: URL,
                     isIncoming: Bool,
                     date: Date,
                     channel: Channel,
                     isHidden: Bool = false,
                     managedContext: NSManagedObjectContext) throws {
        guard let entity = NSEntityDescription.entity(forEntityName: VoiceMessage.EntityName,
                                                      in: managedContext) else {
            throw CoreData.Error.entityNotFound
        }

        self.init(entity: entity, insertInto: managedContext)

        self.identifier = identifier
        self.duration = duration
        self.url = url
        self.isIncoming = isIncoming
        self.date = date
        self.channel = channel
        self.isHidden = isHidden
    }
    
    public override func exportAsUIModel(withId id: Int, status: MessageStatus = .success) -> UIMessageModelProtocol {
        fatalError("Voice message export in not implemented")
    }
}
