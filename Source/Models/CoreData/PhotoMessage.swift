//
//  PhotoMessage+CoreDataClass.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/11/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//
//

import Foundation
import CoreData
import ChattoAdditions

@objc(PhotoMessage)
public class PhotoMessage: Message {
    @NSManaged public var identifier: String
    @NSManaged public var thumbnail: Data
    @NSManaged public var url: URL
    
    private static let EntityName = "PhotoMessage"
    
    convenience init(identifier: String,
                     thumbnail: Data,
                     url: URL,
                     isIncoming: Bool,
                     date: Date,
                     channel: Channel,
                     isHidden: Bool = false,
                     managedContext: NSManagedObjectContext) throws {
        guard let entity = NSEntityDescription.entity(forEntityName: PhotoMessage.EntityName, in: managedContext) else {
            throw CoreData.Error.entityNotFound
        }

        self.init(entity: entity, insertInto: managedContext)

        self.identifier = identifier
        self.thumbnail = thumbnail
        self.url = url
        self.isIncoming = isIncoming
        self.date = date
        self.channel = channel
        self.isHidden = isHidden
    }
    
    public override func exportAsUIModel(withId id: Int, status: MessageStatus = .success) -> UIMessageModelProtocol {
        do {
            let path = try CoreData.shared.getMediaStorage().getPath(name: self.identifier)

            guard let image = UIImage(contentsOfFile: path) else {
                throw NSError()
            }
    
        
//        guard let image = UIImage(data: self.thumbnail) else {
//            Log.error("FIXME")
//            return UITextMessageModel.corruptedModel(uid: id,
//                                                     isIncoming: self.isIncoming,
//                                                     date: self.date)
//       }

       return UIPhotoMessageModel(uid: id,
                                  image: image,
                                  isIncoming: self.isIncoming,
                                  status: status,
                                  date: self.date)
        }
        catch {
            Log.error("FIXME")
            
            return UITextMessageModel.corruptedModel(uid: id,
                                                     isIncoming: self.isIncoming,
                                                     date: self.date)
        }
    }
}
