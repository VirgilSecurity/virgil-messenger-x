//
//  DemoAudioMessageViewModel.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 5/21/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import ChattoAdditions

class DemoAudioMessageViewModel: AudioMessageViewModel<DemoAudioMessageModel>, DemoMessageViewModelProtocol {
    var messageModel: DemoMessageModelProtocol {
        return self.audioMessage
    }
}

class DemoAudioMessageViewModelBuilder: ViewModelBuilderProtocol {

    let messageViewModelBuilder = MessageViewModelDefaultBuilder()

    func createViewModel(_ model: DemoAudioMessageModel) -> DemoAudioMessageViewModel {
        let messageViewModel = self.messageViewModelBuilder.createMessageViewModel(model)
        let audioMessageViewModel = DemoAudioMessageViewModel(audioMessage: model, messageViewModel: messageViewModel)
        audioMessageViewModel.avatarImage.value = UIImage(named: "userAvatar")
        return audioMessageViewModel
    }

    func canCreateViewModel(fromModel model: Any) -> Bool {
        return model is DemoAudioMessageModel
    }
}
