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

        self.navigationItem.title = self.title
        self.navigationController?.navigationBar.tintColor = .white

        self.view.backgroundColor = UIColor(rgb: 0x2B303B)

        self.view.isUserInteractionEnabled = false
        let indicator = UIActivityIndicatorView()
        indicator.hidesWhenStopped = false
        indicator.startAnimating()

        let titleButton = UIButton(type: .custom)
        titleButton.frame = CGRect(x: 0, y: 0, width: 200, height: 21)
        titleButton.tintColor = .white
        titleButton.setTitle("Updating", for: .normal)
        titleButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16.0)

        let titleView = UIStackView(arrangedSubviews: [indicator, titleButton])
        titleView.spacing = 5

        self.navigationItem.titleView = titleView
        self.dataSource.updateMessages {
            if CoreDataHelper.sharedInstance.currentChannel?.type == ChannelType.group.rawValue {
                titleButton.addTarget(self, action: #selector(self.showParticipants), for: .touchUpInside)
            }
            titleButton.setTitle(CoreDataHelper.sharedInstance.currentChannel?.name ?? "Error name", for: .normal)
            self.navigationItem.titleView = titleButton
            self.view.isUserInteractionEnabled = true
            indicator.stopAnimating()
        }

        if CoreDataHelper.sharedInstance.currentChannel?.type == ChannelType.group.rawValue {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self,
                                                                     action: #selector(self.didTapAdd(_:)))
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let title = CoreDataHelper.sharedInstance.currentChannel?.name {
            TwilioHelper.sharedInstance.setChannel(withName: title)
        }
        NotificationCenter.default.removeObserver(self.dataSource)
        self.dataSource.addObserver()
    }

    @objc func showParticipants() {
        self.performSegue(withIdentifier: "goToChatParticipants", sender: self)
    }

    @objc func didTapAdd(_ sender: Any) {
        guard currentReachabilityStatus != .notReachable else {
            let controller = UIAlertController(title: self.title, message: "Please check your network connection", preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(controller, animated: true)

            return
        }

        let alertController = UIAlertController(title: "Add", message: "Enter username", preferredStyle: .alert)

        alertController.addTextField(configurationHandler: {
            $0.placeholder = "Username"
            $0.delegate = self
            $0.keyboardAppearance = UIKeyboardAppearance.dark
        })

        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            guard let username = alertController.textFields?.first?.text else {
                return
            }
            self.addMember(username)
        }))

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in }))

        self.present(alertController, animated: true)
    }

    private func addMember(_ username: String) {
        let username = username.lowercased()

        guard username != TwilioHelper.sharedInstance.username else {
            self.alert("You need to communicate with other people :)")
            return
        }

        guard let currentChannel = CoreDataHelper.sharedInstance.currentChannel else {
            Log.error("Missing current channel")
            return
        }

        if (currentChannel.cards.contains {
            VirgilHelper.sharedInstance.buildCard($0)?.identity == username
        }) {
            self.alert("This user is already member of channel")
        } else {
            HUD.show(.progress)
            VirgilHelper.sharedInstance.getExportedCard(identity: username) { exportedCard, error in
                guard error == nil, let exportedCard = exportedCard else {
                    HUD.flash(.error)
                    return
                }
                TwilioHelper.sharedInstance.invite(member: username) { error in
                    if error == nil {
                        CoreDataHelper.sharedInstance.addMember(card: exportedCard)
                        guard let cards = CoreDataHelper.sharedInstance.currentChannel?.cards else {
                            Log.error("Can't fetch Core Data Cards. Card was not added to encrypt for")
                            HUD.flash(.error)
                            return
                        }
                        VirgilHelper.sharedInstance.setChannelKeys(cards)
                        HUD.flash(.success)
                    } else {
                        HUD.flash(.error)
                    }
                }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self.dataSource)
        NotificationCenter.default.removeObserver(self)
        TwilioHelper.sharedInstance.deselectChannel()
    }

    var chatInputPresenter: BasicChatInputBarPresenter!
    override func createChatInputView() -> UIView {
        let chatInputView = InputBar.loadNib()
        var appearance = ChatInputBarAppearance()

        appearance.textInputAppearance.textColor = .white
        appearance.textInputAppearance.font = appearance.textInputAppearance.font.withSize(CGFloat(20))
        appearance.sendButtonAppearance.titleColors = [
            UIControlStateWrapper(state: UIControlState.disabled) : UIColor(rgb: 0x585A60)
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
        TwilioHelper.sharedInstance.deselectChannel()
    }

    private func alert(_ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

        self.present(alert, animated: true)
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
            if self?.currentReachabilityStatus == .notReachable {
                let controller = UIAlertController(title: nil, message: "Please check your network connection", preferredStyle: .alert)
                controller.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(controller, animated: true)
            } else {
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
            if self?.currentReachabilityStatus == .notReachable {
                let controller = UIAlertController(title: nil, message: "Please check your network connection", preferredStyle: .alert)
                controller.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(controller, animated: true)
            } else {
                self?.dataSource.addPhotoMessage(image)
            }
        }
        return item
    }

    private func createAudioInputItem() -> AudioChatInputItem {
        let item = AudioChatInputItem(presentingController: self)
        item.audioInputHandler = { [weak self] audioData in
            if self?.currentReachabilityStatus == .notReachable {
                let controller = UIAlertController(title: nil, message: "Please check your network connection", preferredStyle: .alert)
                controller.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(controller, animated: true)
            } else {
                self?.dataSource.addAudioMessage(audioData)
            }
        }
        return item
    }
}

extension ChatViewController: AudioPlayableProtocol {
    func play(model: DemoAudioMessageViewModel) {
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(AVAudioSessionPortOverride.speaker)
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
            self.alert("Playing error")
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
        UIApplication.shared.isStatusBarHidden = true
    }

    @objc private func dismissFullscreenImage(_ sender: UITapGestureRecognizer) {
        self.navigationController?.isNavigationBarHidden = false
        sender.view?.removeFromSuperview()
        UIApplication.shared.isStatusBarHidden = false
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
