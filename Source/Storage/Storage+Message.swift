//
//  Storage+Message.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import CoreData
import VirgilCryptoRatchet
import VirgilSDK
import ChattoAdditions

extension Storage {
    @objc(Message)
    public class Message: NSManagedObject, UIMessageModelExportable {
        @NSManaged public var date: Date
        @NSManaged public var isIncoming: Bool
        @NSManaged public var channel: Storage.Channel
        @NSManaged public var isHidden: Bool

        public func exportAsUIModel(withId id: Int, status: MessageStatus = .success) -> UIMessageModelProtocol {
            Log.error(Storage.Error.exportBaseMessageForbidden,
                      message: "Exporting abstract Message to UI model is forbidden")

            return UITextMessageModel.corruptedModel(uid: id,
                                                     isIncoming: self.isIncoming,
                                                     date: self.date)
        }
    }
}
