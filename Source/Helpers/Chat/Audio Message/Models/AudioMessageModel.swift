//
//  AudioMessageModel.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 5/15/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import ChattoAdditions

public protocol AudioMessageModelProtocol: DecoratedMessageModelProtocol {
    var audioUrl: URL { get }
    var duration: TimeInterval { get }
}

open class AudioMessageModel<MessageModelT: MessageModelProtocol>: AudioMessageModelProtocol {
    public let _messageModel: MessageModelT // Can't make messasgeModel: MessageModelT: https://gist.github.com/diegosanchezr/5a66c7af862e1117b556

    public let audioUrl: URL
    public let duration: TimeInterval

    public var identifier: String {
        return self.audioUrl.lastPathComponent
    }

    public var messageModel: MessageModelProtocol {
        return self._messageModel
    }

    public init(messageModel: MessageModelT, audioUrl: URL, duration: TimeInterval) {
        self._messageModel = messageModel
        self.audioUrl = audioUrl
        self.duration = duration
    }
}
