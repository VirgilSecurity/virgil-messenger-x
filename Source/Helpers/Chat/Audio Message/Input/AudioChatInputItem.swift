//
//  AudioChatInputItem.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 5/15/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import ChattoAdditions

open class AudioChatInputItem {
    public typealias Class = AudioChatInputItem
    public var audioInputHandler: ((URL, TimeInterval) -> Void)?
    public var microphonePermissionHandler: (() -> Void)?
    public weak var presentingController: UIViewController?

    let buttonAppearance: TabInputButtonAppearance

    public init(presentingController: UIViewController?,
                tabInputButtonAppearance: TabInputButtonAppearance = Class.createDefaultButtonAppearance()) {
        self.presentingController = presentingController
        self.buttonAppearance = tabInputButtonAppearance
    }

    public static func createDefaultButtonAppearance() -> TabInputButtonAppearance {
        var imageUnselected = UIImage(named: "icon-record-voice-unselected", in: Bundle(for: AudioChatInputItem.self), compatibleWith: nil)!
        imageUnselected = imageUnselected.resize(to: CGSize(width: imageUnselected.size.width - 5, height: imageUnselected.size.height - 9))

        var imageSelected = UIImage(named: "icon-record-voice-selected", in: Bundle(for: AudioChatInputItem.self), compatibleWith: nil)!
        imageSelected = imageSelected.resize(to: CGSize(width: imageSelected.size.width - 5, height: imageSelected.size.height - 9))

        let images: [UIControlStateWrapper: UIImage] = [
            UIControlStateWrapper(state: .normal): imageUnselected,
            UIControlStateWrapper(state: .selected): imageSelected,
            UIControlStateWrapper(state: .highlighted): imageSelected
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
        // TODO: check if this called
        return
    }
}

// MARK: - AudioInputViewDelegate
extension AudioChatInputItem: AudioInputViewDelegate {
    func inputView(_ inputView: AudioInputViewProtocol, didFinishedRecording audioUrl: URL, duration: TimeInterval) {
        self.audioInputHandler?(audioUrl, duration)
    }

    func inputViewDidRequestMicrophonePermission(_ inputView: AudioInputViewProtocol) {
        self.microphonePermissionHandler?()
    }
}
