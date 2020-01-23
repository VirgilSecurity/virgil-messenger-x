//
//  AudioMessageViewModel.swift
//  Morse
//
//  Created by Eugen Pivovarov on 5/15/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import ChattoAdditions

public protocol AudioMessageViewModelProtocol: DecoratedMessageViewModelProtocol {
    var audio: Data { get }
    var duration: TimeInterval { get }
    var state: Observable<PlayingState> { get set }
}

public enum PlayingState {
    case playing
    case paused
    case stopped
}

open class AudioMessageViewModel<AudioMessageModelT: AudioMessageModelProtocol>: AudioMessageViewModelProtocol {
    public let audioMessage: AudioMessageModelT

    open var audio: Data {
        return self.audioMessage.audio
    }

    open var duration: TimeInterval {
        return self.audioMessage.duration
    }

    public var state: Observable<PlayingState> = Observable(.stopped)
    public var messageViewModel: MessageViewModelProtocol

    public init(audioMessage: AudioMessageModelT, messageViewModel: MessageViewModelProtocol) {
        self.audioMessage = audioMessage
        self.messageViewModel = messageViewModel
    }

    open func willBeShown() {
        // Need to declare empty. Otherwise subclass code won't execute (as of Xcode 7.2)
    }

    open func wasHidden() {
        // Need to declare empty. Otherwise subclass code won't execute (as of Xcode 7.2)
    }
}

open class AudioMessageViewModelDefaultBuilder<AudioMessageModelT: AudioMessageModelProtocol>: ViewModelBuilderProtocol {
    public init() {}

    let messageViewModelBuilder = MessageViewModelDefaultBuilder()

    open func createViewModel(_ audioMessage: AudioMessageModelT) -> AudioMessageViewModel<AudioMessageModelT> {
        let messageViewModel = self.messageViewModelBuilder.createMessageViewModel(audioMessage)
        let audioMessageViewModel = AudioMessageViewModel(audioMessage: audioMessage, messageViewModel: messageViewModel)
        return audioMessageViewModel
    }

    open func canCreateViewModel(fromModel model: Any) -> Bool {
        return model is AudioMessageModelT
    }
}
