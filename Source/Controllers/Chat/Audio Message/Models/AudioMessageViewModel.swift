//
//  AudioMessageViewModel.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 5/15/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import ChattoAdditions

public protocol AudioMessageViewModelProtocol: DecoratedMessageViewModelProtocol {
    var audioUrl: URL { get }
    var duration: TimeInterval { get }
    var state: Observable<PlayingState> { get set }
    var transferDirection: Observable<TransferDirection> { get set }
    var transferProgress: Observable<Double> { get  set } // in [0,1]
    var transferStatus: Observable<TransferStatus> { get set }
}

public enum PlayingState {
    case playing
    case paused
    case stopped
}

open class AudioMessageViewModel<AudioMessageModelT: AudioMessageModelProtocol>: AudioMessageViewModelProtocol {
    public let audioMessage: AudioMessageModelT

    open var audioUrl: URL {
        return self.audioMessage.audioUrl
    }

    open var duration: TimeInterval {
        return self.audioMessage.duration
    }

    public var state: Observable<PlayingState> = Observable(.stopped)
    public var messageViewModel: MessageViewModelProtocol

    public var transferStatus: Observable<TransferStatus> = Observable(.idle)
    public var transferProgress: Observable<Double> = Observable(0)
    public var transferDirection: Observable<TransferDirection> = Observable(.download)

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
