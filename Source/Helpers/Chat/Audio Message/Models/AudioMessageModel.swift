//
//  AudioMessageModel.swift
//  Morse
//
//  Created by Eugen Pivovarov on 5/15/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import ChattoAdditions

public protocol AudioMessageModelProtocol: DecoratedMessageModelProtocol {
    var audio: Data { get }
    var duration: TimeInterval { get }
}

open class AudioMessageModel<MessageModelT: MessageModelProtocol>: AudioMessageModelProtocol {
    public var messageModel: MessageModelProtocol {
        return self._messageModel
    }
    public let _messageModel: MessageModelT // Can't make messasgeModel: MessageModelT: https://gist.github.com/diegosanchezr/5a66c7af862e1117b556
    public let audio: Data
    public let duration: TimeInterval
    public init(messageModel: MessageModelT, audio: Data, duration: TimeInterval) {
        self._messageModel = messageModel
        self.audio = audio
        self.duration = duration
    }
}
