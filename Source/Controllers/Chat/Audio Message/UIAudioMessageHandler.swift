//
//  UIAudioMessageHandler.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 5/15/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import ChattoAdditions
import AVFoundation

protocol AudioPlayableProtocol: class, AVAudioPlayerDelegate {
    func play(model: UIAudioMessageViewModel)
    func pause()
    func resume()

    func longPressOnAudio(id: String, isIncoming: Bool)
}

class UIAudioMessageHandler: BaseMessageInteractionHandlerProtocol {
    func userDidSelectMessage(viewModel: UIAudioMessageViewModel) {}

    func userDidDeselectMessage(viewModel: UIAudioMessageViewModel) {}

    private let baseHandler: BaseMessageHandler
    weak private var playableController: AudioPlayableProtocol!
    init (baseHandler: BaseMessageHandler, playableController: AudioPlayableProtocol) {
        self.baseHandler = baseHandler
        self.playableController = playableController
    }

    func userDidTapOnFailIcon(viewModel: UIAudioMessageViewModel, failIconView: UIView) {
        self.baseHandler.userDidTapOnFailIcon(viewModel: viewModel)
    }

    func userDidTapOnAvatar(viewModel: UIAudioMessageViewModel) {
        self.baseHandler.userDidTapOnAvatar(viewModel: viewModel)
    }

    func userDidTapOnBubble(viewModel: UIAudioMessageViewModel) {
        self.baseHandler.userDidTapOnBubble(viewModel: viewModel)

        switch viewModel.state.value {
        case .playing:
            viewModel.state.value = .paused
            self.playableController.pause()
        case .paused:
            viewModel.state.value = .playing
            self.playableController.resume()
        case .stopped:
            viewModel.state.value = .playing
            self.playableController.play(model: viewModel)
        }
    }

    func userDidBeginLongPressOnBubble(viewModel: UIAudioMessageViewModel) {
        self.baseHandler.userDidBeginLongPressOnBubble(viewModel: viewModel)

        self.playableController.longPressOnAudio(id: viewModel.messageModel.uid, isIncoming: viewModel.isIncoming)
    }

    func userDidEndLongPressOnBubble(viewModel: UIAudioMessageViewModel) {
        self.baseHandler.userDidEndLongPressOnBubble(viewModel: viewModel)
    }
}
