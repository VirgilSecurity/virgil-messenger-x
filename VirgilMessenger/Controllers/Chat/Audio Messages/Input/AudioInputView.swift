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
    private var recordButton: UIButton!

    init(presentingController: UIViewController?) {
        super.init(frame: CGRect.zero)
        self.presentingController = presentingController
        self.commonInit()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }

    private func commonInit() {
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.configureButton()
    }

    func configureButton() {
        self.recordButton = UIButton()
        let image = UIImage(named: "record", in: Bundle(for: AudioInputView.self), compatibleWith: nil)!
        recordButton.setImage(image, for: .normal)
        self.recordButton.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(self.recordButton)
        self.addConstraint(NSLayoutConstraint(item: self.recordButton, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.recordButton, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.recordButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 100))
        self.addConstraint(NSLayoutConstraint(item: self.recordButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 100))
    }
}
