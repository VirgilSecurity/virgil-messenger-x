//
//  UIAudioMessageViewModel.swift
//  Morse
//
//  Created by Eugen Pivovarov on 5/21/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import ChattoAdditions

class UIAudioMessageViewModel: AudioMessageViewModel<UIAudioMessageModel>, UIMessageViewModelProtocol {
    var messageModel: UIMessageModelProtocol {
        return self.audioMessage
    }
}

class UIAudioMessageViewModelBuilder: ViewModelBuilderProtocol {

    let messageViewModelBuilder = MessageViewModelDefaultBuilder()

    func createViewModel(_ model: UIAudioMessageModel) -> UIAudioMessageViewModel {
        let messageViewModel = self.messageViewModelBuilder.createMessageViewModel(model)
        let audioMessageViewModel = UIAudioMessageViewModel(audioMessage: model, messageViewModel: messageViewModel)
        audioMessageViewModel.avatarImage.value = UIImage(named: "userAvatar")
        return audioMessageViewModel
    }

    func canCreateViewModel(fromModel model: Any) -> Bool {
        return model is UIAudioMessageModel
    }
}
