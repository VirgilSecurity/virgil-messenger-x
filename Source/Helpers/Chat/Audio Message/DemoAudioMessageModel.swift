//
//  DemoAudioMessageModel.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 5/15/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import ChattoAdditions

public class DemoAudioMessageModel: AudioMessageModel<MessageModel>, DemoMessageModelProtocol {
    public var status: MessageStatus {
        get {
            return self._messageModel.status
        }
        set {
            self._messageModel.status = newValue
        }
    }
}
