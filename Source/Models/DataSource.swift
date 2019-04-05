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
            let corruptedMessage = {
                return MessageFactory.createTextMessageModel("\(0)", text: "Corrupted Message", isIncoming: false,
                                                             status: .success, date: Date())
            }
            guard let sSelf = self,
                let anyMessage = messages[safe: messageNumber],
                let message = anyMessage as? Message,
                let date = message.date,
                let type = message.type else {
                    return corruptedMessage()
            }
            let resultMessage: DemoMessageModelProtocol

            switch type {
            case CoreDataHelper.MessageType.text.rawValue:
                guard let body = message.body else {
                    return corruptedMessage()
                }
                resultMessage = MessageFactory.createTextMessageModel("\(sSelf.nextMessageId)", text: body,
                                                                      isIncoming: message.isIncoming, status: .success,
                                                                      date: date)
            case CoreDataHelper.MessageType.photo.rawValue:
                guard let media = message.media, let image = UIImage(data: media) else {
                    return corruptedMessage()
                }
                resultMessage = MessageFactory.createPhotoMessageModel("\(sSelf.nextMessageId)", image: image,
                                                                       size: image.size, isIncoming: message.isIncoming,
                                                                       status: .success, date: date)
            case CoreDataHelper.MessageType.audio.rawValue:
                guard let media = message.media, let duration = try? AVAudioPlayer(data: media).duration else {
                    return corruptedMessage()
                }
                resultMessage = MessageFactory.createAudioMessageModel("\(sSelf.nextMessageId)", audio: media, duration: duration,
                                                                       isIncoming: message.isIncoming, status: .success, date: date)
            default:
                return corruptedMessage()
            }
            sSelf.nextMessageId += 1

            return resultMessage
        }
        self.delegate?.chatDataSourceDidUpdate(self)
    }

    func addObserver() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(DataSource.processMessage(notification:)),
                                               name: Notification.Name(rawValue: TwilioHelper.Notifications.MessageAddedToSelectedChannel.rawValue),
                                               object: nil)
    }

    func updateMessages(completion: @escaping () -> ()) {
        TwilioHelper.shared.updateMessages(count: self.count) { needToUpdate, _ in
            if needToUpdate > 0 {
                guard let channel = CoreDataHelper.shared.currentChannel,
                    let messages = channel.message else {
                        Log.error("Missing Core Data current channel")
                        completion()
                        return
                }
                for i in (0..<needToUpdate).reversed() {
                    self.slidingWindow.insertItem(self.slidingWindow.itemGenerator(messages.count - i - 1, messages), position: .bottom)
                }
                self.delegate?.chatDataSourceDidUpdate(self)
            }
            completion()
        }
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
        let message = MessageFactory.createPhotoMessageModel(uid, image: image, size: image.size,
                                                             isIncoming: false, status: .sending, date: Date())
        self.messageSender.sendMessage(message)
        self.slidingWindow.insertItem(message, position: .bottom)
        self.delegate?.chatDataSourceDidUpdate(self)
    }

    func addAudioMessage(_ audio: Data) {
        guard let duration = try? AVAudioPlayer(data: audio).duration else {
            Log.error("Getting audio duration failed")
            return
        }
        let uid = "\(self.nextMessageId)"
        self.nextMessageId += 1
        let message = MessageFactory.createAudioMessageModel(uid, audio: audio, duration: duration, isIncoming: false,
                                                             status: .sending, date: Date())
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
