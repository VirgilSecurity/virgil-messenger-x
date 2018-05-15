//
//  AudioInputView.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 5/15/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import ChattoAdditions

protocol AudioInputViewProtocol {
    weak var delegate: AudioInputViewDelegate? { get set }
    weak var presentingController: UIViewController? { get }
}

protocol AudioInputViewDelegate: class {
    func inputView(_ inputView: AudioInputViewProtocol, didFinishedRecoeding audio: Data)
    func inputViewDidRequestMicrophonePermission(_ inputView: AudioInputViewProtocol)
}


class AudioInputView: UIView, AudioInputViewProtocol {
    weak var delegate: AudioInputViewDelegate?
    weak var presentingController: UIViewController?

    init(presentingController: UIViewController?) {
        super.init(frame: CGRect.zero)
        self.presentingController = presentingController
        self.commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }

    private func commonInit() {
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.configureView()
    }

    func configureView() {

    }
}
