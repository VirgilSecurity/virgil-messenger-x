//
//  UIAudioMessageModel.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 5/15/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Chatto
import ChattoAdditions

public class UIAudioMessageModel: AudioMessageModel<MessageModel>, UIMessageModelProtocol {
    public private(set) var state: MediaMessageState
    public private(set) weak var loadDelegate: LoadDelegate?

    public required init(uid: String,
                         audioUrl: URL,
                         duration: TimeInterval,
                         isIncoming: Bool,
                         status: MessageStatus,
                         state: MediaMessageState,
                         date: Date) {
        let senderId = isIncoming ? "1" : "2"

        let messageModel = MessageModel(uid: uid,
                                        senderId: senderId,
                                        type: AudioMessageModel<MessageModel>.chatItemType,
                                        isIncoming: isIncoming,
                                        date: date,
                                        status: status)

        self.state = state

        super.init(messageModel: messageModel, audioUrl: audioUrl, duration: duration)
    }

    public var status: MessageStatus {
        get {
            return self._messageModel.status
        }
        set {
            self._messageModel.status = newValue
        }
    }

    public func set(loadDelegate: LoadDelegate) {
        self.loadDelegate = loadDelegate
    }
}

extension UIAudioMessageModel: LoadDelegate {
    public func progressChanged(to percent: Double) {
        self.loadDelegate?.progressChanged(to: percent)
    }

    public func failed(with error: Error) {
        self.loadDelegate?.failed(with: error)
    }

    public func completed(dataHash: String) {
        self.loadDelegate?.completed(dataHash: dataHash)
    }
}

extension AudioMessageModel {
    static var chatItemType: ChatItemType {
        return "audio"
    }
}
