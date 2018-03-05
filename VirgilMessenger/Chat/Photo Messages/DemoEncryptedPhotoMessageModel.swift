//
//  DemoEncryptedPhotoMessageModel.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 3/5/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation
import ChattoAdditions
import Chatto

public class DemoEncryptedPhotoMessageModel: DemoMessageModelProtocol {
    public var senderId: String

    public var isIncoming: Bool

    public var date: Date

    public var status: MessageStatus

    public var type: ChatItemType

    public var uid: String

    public let encryptedData: Data

    public init(uid: String, encryptedData: Data, isIncoming: Bool,
                status: MessageStatus, date: Date) {
        self.encryptedData = encryptedData
        self.date = date
        self.isIncoming = isIncoming
        self.senderId = ""
        self.status = status
        self.type = "encrypted photo"
        self.uid = uid
    }
}
