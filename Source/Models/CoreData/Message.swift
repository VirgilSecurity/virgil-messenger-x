//
//  Message+CoreDataClass.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/16/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//
//

import CoreData
import UIKit
import AVFoundation
import ChattoAdditions

@objc(Message)
public class Message: NSManagedObject, UIMessageModelExportable {
    @NSManaged public var date: Date
    @NSManaged public var isIncoming: Bool
    @NSManaged public var channel: Channel
    @NSManaged public var isHidden: Bool
    
    public func exportAsUIModel(withId id: Int, status: MessageStatus = .success) -> UIMessageModelProtocol {
        Log.error(CoreData.Error.exportBaseMessageForbidden,
                  message: "Exporting abstract Message to UI model is forbidden")
        
        return UITextMessageModel.corruptedModel(uid: id,
                                                 isIncoming: self.isIncoming,
                                                 date: self.date)
    }
}
