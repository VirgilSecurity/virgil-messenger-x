//
//  UIAudioMessageModel.swift
//  Morse
//
//  Created by Eugen Pivovarov on 5/15/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Chatto
import ChattoAdditions

public class UIAudioMessageModel: AudioMessageModel<MessageModel>, UIMessageModelProtocol {

    public required init(uid: Int,
                         audio: Data,
                         duration: TimeInterval,
                         isIncoming: Bool,
                         status: MessageStatus,
                         date: Date) {
        let senderId = isIncoming ? "1" : "2"

        let messageModel = MessageModel(uid: String(uid),
                                        senderId: senderId,
                                        type: AudioMessageModel<MessageModel>.chatItemType,
                                        isIncoming: isIncoming,
                                        date: date,
                                        status: status)

        super.init(messageModel: messageModel, audio: audio, duration: duration)
    }
    
    public var status: MessageStatus {
        get {
            return self._messageModel.status
        }
        set {
            self._messageModel.status = newValue
        }
    }
}

extension AudioMessageModel {
    static var chatItemType: ChatItemType {
        return "audio"
    }
}

