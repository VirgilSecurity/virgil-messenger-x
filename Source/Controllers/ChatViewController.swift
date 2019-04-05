/*
 The MIT License (MIT)

 Copyright (c) 2015-present Badoo Trading Limited.

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
*/

import UIKit
import Chatto
import ChattoAdditions
import AVFoundation
import PKHUD

class ChatViewController: BaseChatViewController {
    var messageSender: MessageSender!
    private var soundPlayer: AVAudioPlayer?
    weak private var cachedAudioModel: DemoAudioMessageViewModel?
    private var statusBarHidden: Bool = false {
        didSet {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }

    override var prefersStatusBarHidden: Bool {
        return statusBarHidden
    }

    var dataSource: DataSource! {
        didSet {
            self.chatDataSource = self.dataSource
        }
    }

    lazy private var baseMessageHandler: BaseMessageHandler! = {
        return BaseMessageHandler(messageSender: self.messageSender)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        super.chatItemsDecorator = ChatItemsDemoDecorator()

        super.inputContainer.backgroundColor = UIColor(rgb: 0x20232B)
        super.bottomSpaceView.backgroundColor = UIColor(rgb: 0x20232B)
        super.collectionView?.backgroundColor = UIColor(rgb: 0x2B303B)

        self.navigationItem.title = self.title
        self.navigationController?.navigationBar.tintColor = .white

//        self.view.isUserInteractionEnabled = false
//        let indicator = UIActivityIndicatorView()
//        indicator.hidesWhenStopped = false
//        indicator.startAnimating()

        let titleButton = UIButton(type: .custom)
        titleButton.frame = CGRect(x: 0, y: 0, width: 200, height: 21)
        titleButton.tintColor = .white
        titleButton.setTitle("Updating", for: .normal)
        titleButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16.0)

//        let titleView = UIStackView(arrangedSubviews: [indicator, titleButton])
//        titleView.spacing = 5

//        self.navigationItem.titleView = titleView
//        self.dataSource.updateMessages {
            titleButton.setTitle(CoreDataHelper.shared.currentChannel?.name ?? "Error name", for: .normal)
            self.navigationItem.titleView = titleButton
//            self.view.isUserInteractionEnabled = true
//            indicator.stopAnimating()
//        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let title = CoreDataHelper.shared.currentChannel?.name {
            TwilioHelper.shared.setChannel(withName: title)
        }

        if let dataSource = self.dataSource {
            NotificationCenter.default.removeObserver(dataSource)
        }
        
        self.dataSource.addObserver()
    }

    override func viewWillDisappear(_ animated: Bool) {
        if let dataSource = self.dataSource {
            NotificationCenter.default.removeObserver(dataSource)
        }

        NotificationCenter.default.removeObserver(self)
    }

    var chatInputPresenter: BasicChatInputBarPresenter!
    override func createChatInputView() -> UIView {
        let chatInputView = InputBar.loadNib()
        var appearance = ChatInputBarAppearance()

        appearance.textInputAppearance.textColor = .white
        appearance.textInputAppearance.font = appearance.textInputAppearance.font.withSize(CGFloat(20))
        appearance.sendButtonAppearance.titleColors = [
            UIControlStateWrapper(state: UIControl.State.disabled) : UIColor(rgb: 0x585A60)
        ]
        appearance.sendButtonAppearance.font = appearance.textInputAppearance.font

        appearance.sendButtonAppearance.title = NSLocalizedString("Send", comment: "")
        appearance.textInputAppearance.placeholderText = NSLocalizedString("Message...", comment: "")
        appearance.textInputAppearance.placeholderFont = appearance.textInputAppearance.font
        self.chatInputPresenter = BasicChatInputBarPresenter(chatInputBar: chatInputView, chatInputItems: self.createChatInputItems(), chatInputBarAppearance: appearance)
        chatInputView.maxCharactersCount = ChatConstants.chatMaxCharectersCount

        return chatInputView
    }

    override func createPresenterBuilders() -> [ChatItemType: [ChatItemPresenterBuilderProtocol]] {
        let chatColor = BaseMessageCollectionViewCellDefaultStyle.Colors(
            incoming: UIColor(rgb: 0x20232B), // background
            outgoing: UIColor(rgb: 0x4A4E58)
        )

        // used for base message background + text background
        let baseMessageStyle = BaseMessageCollectionViewCellDefaultStyle(colors: chatColor)

        return [
            DemoTextMessageModel.chatItemType: [self.createTextPresenter(with: baseMessageStyle)],
            DemoPhotoMessageModel.chatItemType: [self.createPhotoPresenter(with: baseMessageStyle)],
            DemoAudioMessageModel.chatItemType: [self.createAudioPresenter(with: baseMessageStyle)],
            SendingStatusModel.chatItemType: [SendingStatusPresenterBuilder()],
            TimeSeparatorModel.chatItemType: [TimeSeparatorPresenterBuilder()]
        ]
    }

    func createChatInputItems() -> [ChatInputItemProtocol] {
        var items = [ChatInputItemProtocol]()
        items.append(self.createTextInputItem())
        items.append(self.createPhotoInputItem())
        items.append(self.createAudioInputItem())

        return items
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

/// Presenters creators
extension ChatViewController {
    private func createTextPresenter(with baseMessageStyle: BaseMessageCollectionViewCellDefaultStyle) -> TextMessagePresenterBuilder<DemoTextMessageViewModelBuilder, DemoTextMessageHandler> {
        let textStyle = TextMessageCollectionViewCellDefaultStyle.TextStyle(
            font: UIFont.systemFont(ofSize: 15),
            incomingColor: UIColor(rgb: 0xE4E4E4),
            outgoingColor: UIColor.white, //for outgoing
            incomingInsets: UIEdgeInsets(top: 10, left: 19, bottom: 10, right: 15),
            outgoingInsets: UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 19)
        )

        let textCellStyle: TextMessageCollectionViewCellDefaultStyle = TextMessageCollectionViewCellDefaultStyle(
            textStyle: textStyle,
            baseStyle: baseMessageStyle) // without baseStyle, you won't have the right background

        let textMessagePresenter = TextMessagePresenterBuilder(
            viewModelBuilder: DemoTextMessageViewModelBuilder(),
            interactionHandler: DemoTextMessageHandler(baseHandler: self.baseMessageHandler)
        )
        textMessagePresenter.baseMessageStyle = baseMessageStyle
        textMessagePresenter.textCellStyle = textCellStyle

        return textMessagePresenter
    }

    private func createPhotoPresenter(with baseMessageStyle: BaseMessageCollectionViewCellDefaultStyle) -> PhotoMessagePresenterBuilder<DemoPhotoMessageViewModelBuilder, DemoPhotoMessageHandler> {
        let photoMessagePresenter = PhotoMessagePresenterBuilder(
            viewModelBuilder: DemoPhotoMessageViewModelBuilder(),
            interactionHandler: DemoPhotoMessageHandler(baseHandler: self.baseMessageHandler,
                                                        photoObserverController: self)
        )
        photoMessagePresenter.baseCellStyle = baseMessageStyle

        return photoMessagePresenter
    }

    private func createAudioPresenter(with baseMessageStyle: BaseMessageCollectionViewCellDefaultStyle) -> AudioMessagePresenterBuilder<DemoAudioMessageViewModelBuilder, DemoAudioMessageHandler> {
        let audioTextStyle = AudioMessageCollectionViewCellDefaultStyle.TextStyle(
            font: UIFont.systemFont(ofSize: 15),
            incomingColor: UIColor(rgb: 0xE4E4E4),
            outgoingColor: UIColor.white, //for outgoing
            incomingInsets: UIEdgeInsets(top: 10, left: 19, bottom: 10, right: 15),
            outgoingInsets: UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 19)
        )

        let audioTextCellStyle: AudioMessageCollectionViewCellDefaultStyle = AudioMessageCollectionViewCellDefaultStyle(
            textStyle: audioTextStyle,
            baseStyle: baseMessageStyle) // without baseStyle, you won't have the right background

        let audioMessagePresenter = AudioMessagePresenterBuilder(viewModelBuilder: DemoAudioMessageViewModelBuilder(),
                                                                 interactionHandler: DemoAudioMessageHandler(baseHandler: self.baseMessageHandler, playableController: self))
        audioMessagePresenter.baseMessageStyle = baseMessageStyle
        audioMessagePresenter.textCellStyle = audioTextCellStyle

        return audioMessagePresenter
    }
}

/// ChatInputItems creators
extension ChatViewController {
    private func createTextInputItem() -> TextChatInputItem {
        let item = TextChatInputItem()

        item.textInputHandler = { [weak self] text in
            if self?.checkReachability() ?? false,
                !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self?.dataSource.addTextMessage(text)
            }
        }

        return item
    }

    private func createPhotoInputItem() -> DemoPhotosChatInputItem {
        var liveCamaraAppearence = LiveCameraCellAppearance.createDefaultAppearance()
        liveCamaraAppearence.backgroundColor = UIColor(rgb: 0x2B303B)
        let photosAppearence = PhotosInputViewAppearance(liveCameraCellAppearence: liveCamaraAppearence)
        let item = DemoPhotosChatInputItem(presentingController: self,
                                       tabInputButtonAppearance: PhotosChatInputItem.createDefaultButtonAppearance(),
                                       inputViewAppearance: photosAppearence)

        item.photoInputHandler = { [weak self] image in
            if self?.checkReachability() ?? false {
                self?.dataSource.addPhotoMessage(image)
            }
        }
        return item
    }

    private func createAudioInputItem() -> AudioChatInputItem {
        let item = AudioChatInputItem(presentingController: self)
        item.audioInputHandler = { [weak self] audioData in
            if self?.checkReachability() ?? false {
                self?.dataSource.addAudioMessage(audioData)
            }
        }
        return item
    }
}

extension ChatViewController: AudioPlayableProtocol {
    func play(model: DemoAudioMessageViewModel) {
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
        do {
            self.soundPlayer = try AVAudioPlayer(data: model.audio)
            self.soundPlayer?.delegate = self
            self.soundPlayer?.prepareToPlay()
            self.soundPlayer?.volume = 1.0
            self.soundPlayer?.play()

            if let audioModel = self.cachedAudioModel {
                audioModel.state.value = .stopped
            }
            self.cachedAudioModel = model
        } catch {
            Log.error("AVAudioPlayer error: \(error.localizedDescription)")
            self.alert(UserFriendlyError.playingError)
        }
    }

    func pause() {
        self.soundPlayer?.pause()
    }

    func resume() {
        self.soundPlayer?.prepareToPlay()
        self.soundPlayer?.play()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.cachedAudioModel = nil
    }
}

extension ChatViewController: PhotoObserverProtocol {
    func showImage(_ image: UIImage) {
        self.view.endEditing(true)

        let newImageView = UIImageView()
        newImageView.backgroundColor = .black
        newImageView.frame = UIScreen.main.bounds
        newImageView.contentMode = .scaleAspectFit
        newImageView.image = image
        newImageView.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissFullscreenImage))
        newImageView.addGestureRecognizer(tap)

        self.view.addSubview(newImageView)
        self.navigationController?.isNavigationBarHidden = true
        self.statusBarHidden = true
    }

    @objc private func dismissFullscreenImage(_ sender: UITapGestureRecognizer) {
        self.navigationController?.isNavigationBarHidden = false
        sender.view?.removeFromSuperview()
        self.statusBarHidden = false
    }

    func showSaveImageAlert(_ image: UIImage) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Save to Camera Roll", style: .default) { _ in
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        self.present(alert, animated: true)
    }

    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            let ac = UIAlertController(title: "Save error", message: error.localizedDescription, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(ac, animated: true)
        } else {
            HUD.flash(.success)
        }
    }
}

extension ChatViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }
        if string.rangeOfCharacter(from: ChatConstants.characterSet.inverted) != nil {
            Log.debug("string contains special characters")
            return false
        }
        let newLength = text.count + string.count - range.length
        return newLength <= ChatConstants.limitLength
    }
}
