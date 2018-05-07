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

import Foundation
import Chatto
import ChattoAdditions
import TwilioChatClient

class DataSource: ChatDataSourceProtocol {
    var nextMessageId: Int = 0
    let preferredMaxWindowSize = 500
    private let pageSize: Int
    var slidingWindow: SlidingDataSource<ChatItemProtocol>!

    init(count: Int, pageSize: Int) {
        self.pageSize = pageSize
        self.slidingWindow = SlidingDataSource(count: count, pageSize: pageSize) { [weak self] (count) -> ChatItemProtocol in
            guard let sSelf = self,
                let channel = CoreDataHelper.sharedInstance.currentChannel,
                let messages = channel.message,
                let anyMessage = messages[safe: messages.count - count - 1],
                let message = anyMessage as? Message,
                let messageDate = message.date else {
                    return MessageFactory.createTextMessageModel("\(0)", text: "Corrupted Message", isIncoming: true,
                                                          status: .failed, date: Date())
            }

            let resultMessage: DemoMessageModelProtocol
            if let messageMedia = message.media,
                let image = UIImage(data: messageMedia) {
                    resultMessage = MessageFactory.createPhotoMessageModel("\(sSelf.nextMessageId)", image: image,
                                                                           size: image.size, isIncoming: message.isIncoming,
                                                                           status: .success, date: Date())
            } else if let messageBody = message.body {
                resultMessage = MessageFactory.createTextMessageModel("\(sSelf.nextMessageId)", text: messageBody,
                                                                      isIncoming: message.isIncoming, status: .success,
                                                                      date: messageDate)
            } else {
                resultMessage = MessageFactory.createTextMessageModel("\(sSelf.nextMessageId)", text: "Corrupted Message",
                                                                      isIncoming: true, status: .failed, date: messageDate)
            }

            sSelf.nextMessageId += 1
            return resultMessage
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(DataSource.processMessage(notification:)),
                                               name: Notification.Name(rawValue: TwilioHelper.Notifications.MessageAddedToSelectedChannel.rawValue),
                                                                       object: nil)

    }

    @objc private func processMessage(notification: Notification) {
        Log.debug("processing message")
        guard  let userInfo = notification.userInfo,
            let message = userInfo[TwilioHelper.NotificationKeys.Message.rawValue] as? TCHMessage,
            let messageDate = message.dateUpdatedAsDate else {
            return
        }
        let isIncoming = message.author == TwilioHelper.sharedInstance.username ? false : true

        if message.hasMedia() {
            TwilioHelper.sharedInstance.getMedia(from: message) { encryptedData in
                guard let encryptedData = encryptedData else {
                    Log.error("decryption process of media message failed")
                    return
                }
                guard let encryptedString = String(data: encryptedData, encoding: .utf8),
                    let decryptedString = VirgilHelper.sharedInstance.decryptPFS(encrypted: encryptedString),
                    let decryptedData = Data(base64Encoded: decryptedString),
                    let image = UIImage(data: decryptedData) else {
                        Log.error("decryption process of media failed")
                        return
                }
                CoreDataHelper.sharedInstance.createMediaMessage(withData: decryptedData, isIncoming: true, date: messageDate)

                let model = MessageFactory.createMessageModel("\(self.nextMessageId)", isIncoming: isIncoming,
                                                              type: PhotoMessageModel<MessageModel>.chatItemType,
                                                              status: .success, date: messageDate)
                let decryptedMessage = DemoPhotoMessageModel(messageModel: model, imageSize: image.size, image: image)

                self.slidingWindow.insertItem(decryptedMessage, position: .bottom)
                self.nextMessageId += 1
                self.delegate?.chatDataSourceDidUpdate(self)
            }
        } else if let messageBody = message.body {
            guard let decryptedMessageBody = VirgilHelper.sharedInstance.decryptPFS(encrypted: messageBody) else {
                return
            }
            Log.debug("Receiving " + decryptedMessageBody)

            let model = MessageFactory.createMessageModel("\(self.nextMessageId)", isIncoming: isIncoming, type: TextMessageModel<MessageModel>.chatItemType, status: .success, date: messageDate)
            let decryptedMessage = DemoTextMessageModel(messageModel: model, text: decryptedMessageBody)

            CoreDataHelper.sharedInstance.createTextMessage(withBody: decryptedMessage.body, isIncoming: true, date: messageDate)

            self.slidingWindow.insertItem(decryptedMessage, position: .bottom)
            self.nextMessageId += 1
        }
        self.delegate?.chatDataSourceDidUpdate(self)
    }

    lazy var messageSender: MessageSender = {
        let sender = MessageSender()
        sender.onMessageChanged = { [weak self] message in
            guard let sSelf = self else { return }
            sSelf.delegate?.chatDataSourceDidUpdate(sSelf)
        }
        return sender
    }()

    var hasMoreNext: Bool {
        return self.slidingWindow.hasMore()
    }

    var hasMorePrevious: Bool {
        return self.slidingWindow.hasPrevious()
    }

    var chatItems: [ChatItemProtocol] {
        return self.slidingWindow.itemsInWindow
    }

    weak var delegate: ChatDataSourceDelegateProtocol?

    func loadNext() {
        self.slidingWindow.loadNext()
        self.slidingWindow.adjustWindow(focusPosition: 1, maxWindowSize: self.preferredMaxWindowSize)
        self.delegate?.chatDataSourceDidUpdate(self, updateType: .pagination)
    }

    func loadPrevious() {
        self.slidingWindow.loadPrevious()
        self.slidingWindow.adjustWindow(focusPosition: 0, maxWindowSize: self.preferredMaxWindowSize)
        self.delegate?.chatDataSourceDidUpdate(self, updateType: .pagination)
    }

    func addTextMessage(_ text: String) {
        let uid = "\(self.nextMessageId)"
        self.nextMessageId += 1
        let message = MessageFactory.createTextMessageModel(uid, text: text, isIncoming: false, status: .sending, date: Date())
        self.messageSender.sendMessage(message)
        self.slidingWindow.insertItem(message, position: .bottom)
        self.delegate?.chatDataSourceDidUpdate(self)
    }

    func addPhotoMessage(_ image: UIImage) {
        let uid = "\(self.nextMessageId)"
        self.nextMessageId += 1
        let message = MessageFactory.createPhotoMessageModel(uid, image: image, size: image.size, isIncoming: false, status: .sending, date: Date())
        self.messageSender.sendMessage(message)
        self.slidingWindow.insertItem(message, position: .bottom)
        self.delegate?.chatDataSourceDidUpdate(self)
    }

    func adjustNumberOfMessages(preferredMaxCount: Int?, focusPosition: Double, completion:(_ didAdjust: Bool) -> ()) {
        let didAdjust = self.slidingWindow.adjustWindow(focusPosition: focusPosition, maxWindowSize: preferredMaxCount ?? self.preferredMaxWindowSize)
        completion(didAdjust)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
