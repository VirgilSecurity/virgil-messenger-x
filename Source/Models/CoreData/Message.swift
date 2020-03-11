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
public class Message: NSManagedObject {
    @NSManaged public var date: Date
    @NSManaged public var isIncoming: Bool
    @NSManaged public var channel: Channel
    @NSManaged public var isHidden: Bool
    
    public var type: MessageType {
        if self is TextMessage {
            return .text
        }
        else {
            fatalError("Unknown subclass of Message")
        }
    }
}

extension Message {
    public func exportAsUIModel(withId id: Int, status: MessageStatus = .success) -> UIMessageModelProtocol {
        let resultMessage: UIMessageModelProtocol

        if let message = self as? TextMessage {
            resultMessage = UITextMessageModel(uid: id,
                                               text: message.body,
                                               isIncoming: self.isIncoming,
                                               status: status,
                                               date: date)
        }
        if let callMessage = self as? CallMessage {
            resultMessage = UITextMessageModel(uid: id,
                                               text: "Call...",
                                               isIncoming: self.isIncoming,
                                               status: status,
                                               date: date)
        }
        else {
            Log.error("Exporting core data model to ui model failed")
            
            resultMessage = UITextMessageModel.corruptedModel(uid: id,
                                                              isIncoming: self.isIncoming,
                                                              date: self.date)
        }
        
        return resultMessage
    }
}
