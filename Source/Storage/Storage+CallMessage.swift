//
//  Storage.CallMessage.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 12.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import CoreData
import ChattoAdditions

extension Storage {
    @objc(CallMessage)
    public class CallMessage: Message {
        @NSManaged public var channelName: String
        @NSManaged public var duration: TimeInterval

        private static let EntityName = "CallMessage"

        convenience init(xmppId: String,
                         isIncoming: Bool,
                         date: Date,
                         channel: Channel,
                         isHidden: Bool = false,
                         managedContext: NSManagedObjectContext) throws {
            guard let entity = NSEntityDescription.entity(forEntityName: CallMessage.EntityName, in: managedContext) else {
                throw Storage.Error.entityNotFound
            }

            self.init(entity: entity, insertInto: managedContext)

            self.channelName = channel.name
            self.xmppId = xmppId
            self.isIncoming = isIncoming
            self.date = date
            self.channel = channel
            self.isHidden = isHidden
        }

        public override func exportAsUIModel(withId id: Int, status: MessageStatus = .success) -> UIMessageModelProtocol {
            let text = self.isIncoming ? "Incomming call from \(self.channelName)" : "Outgoing call to \(self.channelName)"

            return UITextMessageModel(uid: id,
                                      text: text,
                                      isIncoming: self.isIncoming,
                                      status: status,
                                      date: date)
        }
    }
}
