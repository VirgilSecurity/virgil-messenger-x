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

class ChatViewController: BaseChatViewController {
    var messageSender: MessageSender!

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

        let titleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))
        titleLabel.textColor = .white
        titleLabel.text = "Updating"
        let titleView = UIStackView(arrangedSubviews: [indicator, titleLabel])
        titleView.spacing = 5

        self.navigationItem.titleView = titleView
        self.dataSource.updateMessages {
            self.navigationItem.titleView = nil
            self.title = TwilioHelper.sharedInstance.getCompanion(ofChannel: TwilioHelper.sharedInstance.currentChannel)
            self.view.isUserInteractionEnabled = true
            indicator.stopAnimating()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self.dataSource)
        NotificationCenter.default.removeObserver(self)
        TwilioHelper.sharedInstance.deselectChannel()
        VirgilHelper.sharedInstance.setChannelCard(nil)
    }

    var chatInputPresenter: BasicChatInputBarPresenter!
    override func createChatInputView() -> UIView {
        let chatInputView = InputBar.loadNib()
        var appearance = ChatInputBarAppearance()
        appearance.textInputAppearance.textColor = .white
        appearance.textInputAppearance.font = appearance.textInputAppearance.font.withSize(CGFloat(20))
        appearance.sendButtonAppearance.titleColors = [UIControlStateWrapper(state: UIControlState.disabled) : UIColor(rgb: 0x585A60)]
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

        let textStyle = TextMessageCollectionViewCellDefaultStyle.TextStyle(
            font: UIFont.systemFont(ofSize: 15),
            incomingColor: UIColor(rgb: 0xE4E4E4),
            outgoingColor: UIColor.white, //for outgoing
            incomingInsets: UIEdgeInsets(top: 10, left: 19, bottom: 10, right: 15),
            outgoingInsets: UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 19)
        )

        let audioTextStyle = AudioMessageCollectionViewCellDefaultStyle.TextStyle(
            font: UIFont.systemFont(ofSize: 15),
            incomingColor: UIColor(rgb: 0xE4E4E4),
            outgoingColor: UIColor.white, //for outgoing
            incomingInsets: UIEdgeInsets(top: 10, left: 19, bottom: 10, right: 15),
            outgoingInsets: UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 19)
        )

        let textCellStyle: TextMessageCollectionViewCellDefaultStyle = TextMessageCollectionViewCellDefaultStyle(
            textStyle: textStyle,
            baseStyle: baseMessageStyle) // without baseStyle, you won't have the right background

        let audioTextCellStyle: AudioMessageCollectionViewCellDefaultStyle = AudioMessageCollectionViewCellDefaultStyle(
            textStyle: audioTextStyle,
            baseStyle: baseMessageStyle) // without baseStyle, you won't have the right background

        let textMessagePresenter = TextMessagePresenterBuilder(
            viewModelBuilder: DemoTextMessageViewModelBuilder(),
            interactionHandler: DemoTextMessageHandler(baseHandler: self.baseMessageHandler)
        )
        textMessagePresenter.baseMessageStyle = baseMessageStyle
        textMessagePresenter.textCellStyle = textCellStyle

        let photoMessagePresenter = PhotoMessagePresenterBuilder(
            viewModelBuilder: DemoPhotoMessageViewModelBuilder(),
            interactionHandler: DemoPhotoMessageHandler(baseHandler: self.baseMessageHandler,
                                                        presenterController: self)
        )
        photoMessagePresenter.baseCellStyle = baseMessageStyle

        let audioMessagePresenter = AudioMessagePresenterBuilder(viewModelBuilder: DemoAudioMessageViewModelBuilder(),
                                                                 interactionHandler: DemoAudioMessageHandler(baseHandler: self.baseMessageHandler))
        audioMessagePresenter.baseMessageStyle = baseMessageStyle
        audioMessagePresenter.textCellStyle = audioTextCellStyle

        return [
            DemoTextMessageModel.chatItemType: [textMessagePresenter],
            DemoPhotoMessageModel.chatItemType: [photoMessagePresenter],
            DemoAudioMessageModel.chatItemType: [audioMessagePresenter],
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
        VirgilHelper.sharedInstance.setChannelCard(nil)
    }

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

    private func createPhotoInputItem() -> PhotosChatInputItem {
        var liveCamaraAppearence = LiveCameraCellAppearance.createDefaultAppearance()
        liveCamaraAppearence.backgroundColor = UIColor(rgb: 0x2B303B)
        let photosAppearence = PhotosInputViewAppearance(liveCameraCellAppearence: liveCamaraAppearence)
        let item = PhotosChatInputItem(presentingController: self,
                                       tabInputButtonAppearance: PhotosChatInputItem.createDefaultButtonAppearance(),
                                       inputViewAppearance: photosAppearence)


        if let subviews = item.inputView?.subviews {
            for subview in subviews {
                subview.backgroundColor = UIColor(rgb: 0x20232B)
            }
        }

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
}
