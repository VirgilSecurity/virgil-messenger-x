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

import Chatto
import ChattoAdditions
import AVFoundation
import VirgilSDK

class DataSource: ChatDataSourceProtocol {
    public let channel: Channel
    public var nextMessageId: Int = 0

    private let preferredMaxWindowSize = 500
    private var slidingWindow: SlidingDataSource<ChatItemProtocol>!

    private var count: Int {
        return self.channel.visibleMessages.count
    }

    init(channel: Channel) {
        self.channel = channel

        self.slidingWindow = SlidingDataSource(count: count) { [weak self] (messageNumber, messages) -> ChatItemProtocol in
            self?.nextMessageId += 1
            let id = self?.nextMessageId ?? 0

            guard self != nil,
                let message = messages[safe: messageNumber] else {
                    return UITextMessageModel.corruptedModel(uid: id)
            }

            return message.exportAsUIModel(withId: id)
        }

        self.delegate?.chatDataSourceDidUpdate(self)
    }

    func setupObservers() {
        let process: Notifications.Block = { [weak self] notification in
            do {
                let message: Message = try Notifications.parse(notification, for: .message)
                
                self?.process(message: message)
            }
            catch {
                Log.error(error, message: "Parsing Message notification failed")
            }
        }

        let updateMessageList: Notifications.Block = { [weak self] _ in
            guard let strongSelf = self else { return }

            strongSelf.slidingWindow.updateMessageList()

            DispatchQueue.main.async {
                strongSelf.delegate?.chatDataSourceDidUpdate(strongSelf, updateType: .messageCountReduction)
            }
        }

        Notifications.observe(for: .messageAddedToCurrentChannel, block: process)
        Notifications.observe(for: .updatingSucceed, block: updateMessageList)
    }

    @objc private func process(message: Message) {
        self.nextMessageId += 1
        let uiModel = message.exportAsUIModel(withId: self.nextMessageId)
        
        DispatchQueue.main.async {
            self.slidingWindow.insertItem(uiModel, position: .bottom)
            self.delegate?.chatDataSourceDidUpdate(self)
        }
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

        let uiModel = UITextMessageModel(uid: id,
                                         text: text,
                                         isIncoming: false,
                                         status: .sending,
                                         date: Date())

        self.messageSender.send(uiModel: uiModel, channel: self.channel)

        self.slidingWindow.insertItem(uiModel, position: .bottom)
        self.delegate?.chatDataSourceDidUpdate(self)
    }

    func addPhotoMessage(_ image: UIImage) {
        self.nextMessageId += 1
        let id = self.nextMessageId
        
        let uiModel = UIPhotoMessageModel(uid: id,
                                          image: image,
                                          isIncoming: false,
                                          status: .sending,
                                          state: .uploading,
                                          date: Date())
        
        self.slidingWindow.insertItem(uiModel, position: .bottom)
        self.delegate?.chatDataSourceDidUpdate(self)
        
        self.messageSender.send(uiModel: uiModel, channel: self.channel)
    }

    func addVoiceMessage(_ audioUrl: URL, duration: TimeInterval) {
        self.nextMessageId += 1
        let id = self.nextMessageId

        let uiModel = UIAudioMessageModel(uid: id,
                                          audioUrl: audioUrl,
                                          duration: duration,
                                          isIncoming: false,
                                          status: .sending,
                                          state: .uploading,
                                          date: Date())
        
        self.slidingWindow.insertItem(uiModel, position: .bottom)
        self.delegate?.chatDataSourceDidUpdate(self)
        
        self.messageSender.send(uiModel: uiModel, channel: self.channel)
    }

    func adjustNumberOfMessages(preferredMaxCount: Int?, focusPosition: Double, completion:(_ didAdjust: Bool) -> ()) {
        let didAdjust = self.slidingWindow.adjustWindow(focusPosition: focusPosition,
                                                        maxWindowSize: preferredMaxCount ?? self.preferredMaxWindowSize)
        completion(didAdjust)
    }
}
