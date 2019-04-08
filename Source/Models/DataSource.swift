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
import AVFoundation

class DataSource: ChatDataSourceProtocol {
    let count: Int
    var nextMessageId: Int = 0
    let preferredMaxWindowSize = 500
    private let pageSize: Int
    var slidingWindow: SlidingDataSource<ChatItemProtocol>!

    init(count: Int, pageSize: Int) {
        self.pageSize = pageSize
        self.count = count

        self.slidingWindow = SlidingDataSource(count: count, pageSize: pageSize) { [weak self] (messageNumber, messages) -> ChatItemProtocol in
            self?.nextMessageId += 1
            let id = self?.nextMessageId ?? 0

            guard self != nil,
                let anyMessage = messages[safe: messageNumber],
                let message = anyMessage as? Message else {
                    return MessageFactory.createCorruptedMessageModel(uid: id)
            }

            return message.exportAsUIModel(withId: id)
        }

        self.delegate?.chatDataSourceDidUpdate(self)
    }

    func addObserver() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(DataSource.processMessage(notification:)),
                                               name: Notification.Name(rawValue: TwilioHelper.Notifications.MessageAddedToSelectedChannel.rawValue),
                                               object: nil)
    }

    @objc private func processMessage(notification: Notification) {
        guard let userInfo = notification.userInfo,
            let message = userInfo[TwilioHelper.NotificationKeys.Message.rawValue] as? Message else {
                return
        }

        self.nextMessageId += 1
        let uiModel = message.exportAsUIModel(withId: self.nextMessageId)

        self.slidingWindow.insertItem(uiModel, position: .bottom)
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
        self.nextMessageId += 1
        let id = self.nextMessageId
        let message = MessageFactory.createTextMessageModel(uid: id,
                                                            text: text,
                                                            isIncoming: false,
                                                            status: .sending)
        self.messageSender.sendMessage(message)
        self.slidingWindow.insertItem(message, position: .bottom)
        self.delegate?.chatDataSourceDidUpdate(self)
    }

    func addPhotoMessage(_ image: UIImage) {
        self.nextMessageId += 1
        let id = self.nextMessageId
        let message = MessageFactory.createPhotoMessageModel(uid: id,
                                                             image: image,
                                                             size: image.size,
                                                             isIncoming: false,
                                                             status: .sending)
        self.messageSender.sendMessage(message)
        self.slidingWindow.insertItem(message, position: .bottom)
        self.delegate?.chatDataSourceDidUpdate(self)
    }

    func addAudioMessage(_ audio: Data) {
        self.nextMessageId += 1
        let id = self.nextMessageId

        let message: DemoMessageModelProtocol

        // FIXME
        if let duration = try? AVAudioPlayer(data: audio).duration {
            message = MessageFactory.createAudioMessageModel(uid: id,
                                                             audio: audio,
                                                             duration: duration,
                                                             isIncoming: false,
                                                             status: .sending)
        } else {
            Log.error("Getting audio duration failed")
            message = MessageFactory.createCorruptedMessageModel(uid: id)
            return
        }

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
