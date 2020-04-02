//
//  Message+CoreDataClass.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/16/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//
//

import CoreData
import ChattoAdditions

@objc(Message)
public class Message: NSManagedObject, UIMessageModelExportable {
    @NSManaged public var xmppId: String
    @NSManaged public var date: Date
    @NSManaged public var isIncoming: Bool
    @NSManaged public var channel: Channel
    @NSManaged public var isHidden: Bool
    
    public struct Params {
        var xmppId: String
        var isIncoming: Bool
        var channel: Channel
        var date: Date = Date()
        var isHidden: Bool = false
    }
    
    convenience public init(entityName: String, context: NSManagedObjectContext, params: Params) throws {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
            throw CoreData.Error.entityNotFound
        }
        
        self.init(entity: entity, insertInto: context)
        
        self.xmppId = params.xmppId
        self.date = params.date
        self.isIncoming = params.isIncoming
        self.channel = params.channel
        self.isHidden = params.isHidden
    }
        
    public func exportAsUIModel(withId id: Int, status: MessageStatus = .success) -> UIMessageModelProtocol {
        Log.error(CoreData.Error.exportBaseMessageForbidden,
                  message: "Exporting abstract Message to UI model is forbidden")
        
        return UITextMessageModel.corruptedModel(uid: id,
                                                 isIncoming: self.isIncoming,
                                                 date: self.date)
    }
}
