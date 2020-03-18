//
//  UIAudioMessageViewModel.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 5/21/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import ChattoAdditions

class UIAudioMessageViewModel: AudioMessageViewModel<UIAudioMessageModel>, UIMessageViewModelProtocol {
    private var loadState: MediaMessageState
    
    var messageModel: UIMessageModelProtocol {
        return self.audioMessage
    }
    
    override init(audioMessage: UIAudioMessageModel, messageViewModel: MessageViewModelProtocol) {
        self.loadState = audioMessage.state
        
        super.init(audioMessage: audioMessage, messageViewModel: messageViewModel)
        
        switch audioMessage.state {
        case .downloading, .uploading:
            self.transferStatus.value = .transfering

            audioMessage.set(loadDelegate: self)
        case .normal:
            break
        }
    }
}

extension UIAudioMessageViewModel: LoadDelegate {
    func progressChanged(to percent: Double) {
        DispatchQueue.main.async {
            guard self.transferStatus.value == .transfering else {
                // FIXME: add error logs
                return
            }
            guard percent < 100 else {
                self.transferStatus.value = .success
                return
            }
            
            self.transferProgress.value = percent
        }
    }
    
    func failed(with error: Error) {
        // FIXME: add error logs
        DispatchQueue.main.async {
            self.transferStatus.value = .failed
            self.loadState = .normal
        }
    }
    
    func completed(dataHash: String) {
        // FIXME: copypaste
        DispatchQueue.main.async {
            self.transferStatus.value = .success
            self.loadState = .normal
        }
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
