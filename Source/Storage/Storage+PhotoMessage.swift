//
//  Storgae+PhotoMessage.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/11/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//
//

import Foundation
import CoreData
import ChattoAdditions

extension Storage {
    @objc(PhotoMessage)
    public class PhotoMessage: Message {
        @NSManaged public var identifier: String
        @NSManaged public var thumbnail: Data
        @NSManaged public var url: URL

        private static let EntityName = "PhotoMessage"

        convenience init(identifier: String,
                         thumbnail: Data,
                         url: URL,
                         xmppId: String,
                         isIncoming: Bool,
                         date: Date,
                         channel: Channel,
                         isHidden: Bool = false,
                         managedContext: NSManagedObjectContext) throws {
            guard let entity = NSEntityDescription.entity(forEntityName: PhotoMessage.EntityName, in: managedContext) else {
                throw Storage.Error.entityNotFound
            }

            self.init(entity: entity, insertInto: managedContext)

            self.identifier = identifier
            self.thumbnail = thumbnail
            self.url = url
            self.xmppId = xmppId
            self.isIncoming = isIncoming
            self.date = date
            self.channel = channel
            self.isHidden = isHidden
        }

        func thumbnailImage() throws -> UIImage {
            guard let image = UIImage(data: self.thumbnail) else {
                throw Storage.Error.invalidMessage
            }

            return image
        }
    }
}
