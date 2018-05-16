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
    func inputView(_ inputView: AudioInputViewProtocol, didFinishedRecording audio: Data)
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
        self.translatesAutoresizingMaskIntoConstraints = false
        self.configureButton()
    }

    func configureButton() {
        let view = UIView(frame: CGRect.zero)
        view.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(view)
        self.addConstraint(NSLayoutConstraint(item: view, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: view, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: view, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: view, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: 0))

        let lineView = UIView(frame: CGRect.zero)
        lineView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(lineView)

        let textLabel = UILabel.init(frame: CGRect.zero)
        textLabel.textAlignment = .center
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.text = "time"
        textLabel.textColor = .white
        view.addSubview(textLabel)

        self.addConstraint(NSLayoutConstraint(item: lineView, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: lineView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 100))
        self.addConstraint(NSLayoutConstraint(item: lineView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 100))
        self.addConstraint(NSLayoutConstraint(item: lineView, attribute: .bottom, relatedBy: .equal, toItem: textLabel, attribute: .top, multiplier: 1, constant: -10))

        self.recordButton = UIButton(frame: CGRect.zero)
        let image = UIImage(named: "record", in: Bundle(for: AudioInputView.self), compatibleWith: nil)!
        self.recordButton.setImage(image, for: .normal)
        self.recordButton.translatesAutoresizingMaskIntoConstraints = false
        self.recordButton.addTarget(self, action: #selector(didStartRecord(_:)), for: .touchUpInside)

        view.addSubview(self.recordButton)
        self.addConstraint(NSLayoutConstraint(item: textLabel, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: textLabel, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 100))
        self.addConstraint(NSLayoutConstraint(item: textLabel, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 100))
        self.addConstraint(NSLayoutConstraint(item: textLabel, attribute: .bottom, relatedBy: .equal, toItem: self.recordButton, attribute: .top, multiplier: 1, constant: -20))

        self.addConstraint(NSLayoutConstraint(item: self.recordButton, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.recordButton, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1, constant: -30))
        self.addConstraint(NSLayoutConstraint(item: self.recordButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 100))
        self.addConstraint(NSLayoutConstraint(item: self.recordButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 100))
    }

    @objc func didStartRecord(_ sender: Any) {
        self.recordButton.backgroundColor = .red
    }
}
