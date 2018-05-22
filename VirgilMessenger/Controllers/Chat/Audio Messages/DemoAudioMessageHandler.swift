//
//  DemoAudioMessageHandler.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 5/15/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import ChattoAdditions
import AVFoundation

protocol AudioPlayableProtocol: class, AVAudioPlayerDelegate {
    func play(data: Data)
}

class DemoAudioMessageHandler: BaseMessageInteractionHandlerProtocol {
    func userDidSelectMessage(viewModel: DemoAudioMessageViewModel) {}

    func userDidDeselectMessage(viewModel: DemoAudioMessageViewModel) {}

    private let baseHandler: BaseMessageHandler
    weak private var playableController: AudioPlayableProtocol!
    init (baseHandler: BaseMessageHandler, playableController: AudioPlayableProtocol) {
        self.baseHandler = baseHandler
        self.playableController = playableController
    }

    func userDidTapOnFailIcon(viewModel: DemoAudioMessageViewModel, failIconView: UIView) {
        self.baseHandler.userDidTapOnFailIcon(viewModel: viewModel)
    }

    func userDidTapOnAvatar(viewModel: DemoAudioMessageViewModel) {
        self.baseHandler.userDidTapOnAvatar(viewModel: viewModel)
    }

    func userDidTapOnBubble(viewModel: DemoAudioMessageViewModel) {
        self.baseHandler.userDidTapOnBubble(viewModel: viewModel)
        self.playableController.play(data: viewModel.audio)
    }

    func userDidBeginLongPressOnBubble(viewModel: DemoAudioMessageViewModel) {
        self.baseHandler.userDidBeginLongPressOnBubble(viewModel: viewModel)
    }

    func userDidEndLongPressOnBubble(viewModel: DemoAudioMessageViewModel) {
        self.baseHandler.userDidEndLongPressOnBubble(viewModel: viewModel)
    }
}
