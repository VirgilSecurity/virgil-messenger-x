//
//  Storgae+PhotoMessage.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/11/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//
//

import CoreData
import UIKit

extension Storage {
    @objc(PhotoMessage)
    public class PhotoMessage: Message {
        @NSManaged public var identifier: String
        @NSManaged public var thumbnail: Data
        @NSManaged public var url: URL
        @NSManaged public var secret: Data

        private static let EntityName = "PhotoMessage"

        convenience init(identifier: String,
                         thumbnail: Data,
                         url: URL,
                         secret: Data,
                         baseParams: Message.Params,
                         context: NSManagedObjectContext) throws {
            try self.init(entityName: PhotoMessage.EntityName, context: context, params: baseParams)

            self.identifier = identifier
            self.thumbnail = thumbnail
            self.url = url
            self.secret = secret
        }


        func thumbnailImage() throws -> UIImage {
            guard let image = UIImage(data: self.thumbnail) else {
                throw Storage.Error.invalidMessage
            }

            return image
        }
    }
}
