//
//  AudioChatInputItem.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 5/15/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import ChattoAdditions

open class AudioChatInputItem {
    typealias Class = AudioChatInputItem
    public var audioInputHandler: ((Data) -> Void)?
    public var microphonePermissionHandler: (() -> Void)?
    public weak var presentingController: UIViewController?

    let buttonAppearance: TabInputButtonAppearance

    public init(presentingController: UIViewController?,
                tabInputButtonAppearance: TabInputButtonAppearance = Class.createDefaultButtonAppearance()) {
        self.presentingController = presentingController
        self.buttonAppearance = tabInputButtonAppearance
    }

    public static func createDefaultButtonAppearance() -> TabInputButtonAppearance {
        let images: [UIControlStateWrapper: UIImage] = [
            UIControlStateWrapper(state: .normal): UIImage(named: "microphone", in: Bundle(for: AudioChatInputItem.self), compatibleWith: nil)!,
            UIControlStateWrapper(state: .selected): UIImage(named: "microphone", in: Bundle(for: AudioChatInputItem.self), compatibleWith: nil)!,
            UIControlStateWrapper(state: .highlighted): UIImage(named: "microphone", in: Bundle(for: AudioChatInputItem.self), compatibleWith: nil)!
        ]
        return TabInputButtonAppearance(images: images, size: nil)
    }

    lazy fileprivate var internalTabView: TabInputButton = {
        return TabInputButton.makeInputButton(withAppearance: self.buttonAppearance, accessibilityID: "audio.chat.input.view")
    }()

    lazy var audioInputView: AudioInputViewProtocol = {
        let audioInputView = AudioInputView(presentingController: self.presentingController)
        audioInputView.delegate = self
        return audioInputView
    }()

    open var selected = false {
        didSet {
            self.internalTabView.isSelected = self.selected
        }
    }
}

// MARK: - ChatInputItemProtocol
extension AudioChatInputItem: ChatInputItemProtocol {
    public var presentationMode: ChatInputItemPresentationMode {
        return .customView
    }

    public var showsSendButton: Bool {
        return false
    }

    public var inputView: UIView? {
        return self.audioInputView as? UIView
    }

    public var tabView: UIView {
        return self.internalTabView
    }

    public func handleInput(_ input: AnyObject) {
        if let audio = input as? Data {
            self.audioInputHandler?(audio)
        }
    }
}

// MARK: - AudioInputViewDelegate
extension AudioChatInputItem: AudioInputViewDelegate {
    func inputView(_ inputView: AudioInputViewProtocol, didFinishedRecording audio: Data) {
        self.audioInputHandler?(audio)
    }

    func inputViewDidRequestMicrophonePermission(_ inputView: AudioInputViewProtocol) {
        self.microphonePermissionHandler?()
    }
}

