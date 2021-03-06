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
    public let channel: Storage.Channel

    private let preferredMaxWindowSize = 500
    private var slidingWindow: SlidingDataSource<ChatItemProtocol>!

    public enum Error: Int, Swift.Error, LocalizedError {
        case chatItemIsNotUIMessageModel = 1
    }

    private var count: Int {
        return self.channel.visibleMessages.count
    }

    init(channel: Storage.Channel) {
        self.channel = channel

        self.slidingWindow = SlidingDataSource(count: count) { [weak self] (messageNumber, messages) -> ChatItemProtocol in
            guard self != nil,
                let message = messages[safe: messageNumber] else {
                    return UITextMessageModel.corruptedModel(uid: UUID().uuidString)
            }

            return Storage.exportAsUIModel(message: message)
        }

        self.delegate?.chatDataSourceDidUpdate(self)
    }

    func setupObservers() {
        let process: Notifications.Block = { [weak self] notification in
            do {
                let message: Storage.Message = try Notifications.parse(notification, for: .message)

                self?.process(message: message)
            }
            catch {
                Log.error(error, message: "Parsing Message notification failed")
            }
        }

        let connectionStateChanged: Notifications.Block = { [weak self] _ in
            guard let strongSelf = self else { return }

            guard Ejabberd.shared.state == .connected else {
                return
            }

            do {
                try Ejabberd.shared.sendGlobalReadReceipt(to: strongSelf.channel.name)

                strongSelf.slidingWindow.updateMessageList()

                DispatchQueue.main.async {
                    strongSelf.delegate?.chatDataSourceDidUpdate(strongSelf, updateType: .messageCountReduction)
                }
            }
            catch {
                Log.error(error, message: "Sending global read response failed")
            }
        }

        let updateMessageState: Notifications.Block = { [weak self] notification in
            guard let strongSelf = self else { return }

            do {
                let messageIds: [String] = try Notifications.parse(notification, for: .messageIds)
                let newState: Storage.Message.State = try Notifications.parse(notification, for: .newState)

                let selectPredicate = { (item: ChatItemProtocol) -> Bool in
                    messageIds.contains(item.uid)
                }

                let changePredicate = { (item: ChatItemProtocol) throws -> ChatItemProtocol in
                    guard let item = item as? UIMessageModelProtocol else {
                        throw Error.chatItemIsNotUIMessageModel
                    }

                    item.status = newState.exportAsMessageStatus()

                    return item
                }

                try strongSelf.slidingWindow.updateItems(where: selectPredicate, changePredicate: changePredicate)
            }
            catch {
                Log.error(error, message: "NewState notification processing failed")
            }

            DispatchQueue.main.async {
                strongSelf.delegate?.chatDataSourceDidUpdate(strongSelf)
            }
        }

        Notifications.observe(for: .messageAddedToCurrentChannel, block: process)
        Notifications.observe(for: .messageStatusUpdated, block: updateMessageState)
        Notifications.observe(for: .connectionStateChanged, block: connectionStateChanged)
    }

    @objc private func process(message: Storage.Message) {
        let uiModel = Storage.exportAsUIModel(message: message)

        DispatchQueue.main.async {
            self.slidingWindow.insertItem(uiModel, position: .bottom)
            self.delegate?.chatDataSourceDidUpdate(self)
        }
    }

    lazy var messageSender: MessageSender = {
        let sender = MessageSender()
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
        let messageId = UUID().uuidString

        let uiModel = UITextMessageModel(uid: messageId,
                                         text: text,
                                         isIncoming: false,
                                         status: .sending,
                                         date: Date())

        let message = NetworkMessage.Text(body: text)

        self.slidingWindow.insertItem(uiModel, position: .bottom)
        self.delegate?.chatDataSourceDidUpdate(self)

        self.messageSender.send(text: message, date: uiModel.date, channel: self.channel, messageId: messageId) { error in
            self.updateMessageStatus(uiModel, error)
        }
    }

    func addPhotoMessage(_ image: UIImage) {
        let messageId = UUID().uuidString

        let uiModel = UIPhotoMessageModel(uid: messageId,
                                          image: image,
                                          isIncoming: false,
                                          status: .sending,
                                          state: .uploading,
                                          date: Date())

        self.slidingWindow.insertItem(uiModel, position: .bottom)
        self.delegate?.chatDataSourceDidUpdate(self)

        self.messageSender.uploadAndSend(image: image, date: uiModel.date, channel: self.channel, messageId: messageId, loadDelegate: uiModel) { error in
            self.updateMessageStatus(uiModel, error)
        }
    }

    func addVoiceMessage(_ audioUrl: URL, duration: TimeInterval) {
        let messageId = UUID().uuidString

        let uiModel = UIAudioMessageModel(uid: messageId,
                                          audioUrl: audioUrl,
                                          duration: duration,
                                          isIncoming: false,
                                          status: .sending,
                                          state: .uploading,
                                          date: Date())

        self.slidingWindow.insertItem(uiModel, position: .bottom)
        self.delegate?.chatDataSourceDidUpdate(self)

        self.messageSender.uploadAndSend(voice: uiModel.audioUrl,
                                         identifier: uiModel.identifier,
                                         duration: uiModel.duration,
                                         date: uiModel.date,
                                         channel: self.channel,
                                         messageId: messageId,
                                         loadDelegate: uiModel) { error in
            self.updateMessageStatus(uiModel, error)
        }
    }

    func adjustNumberOfMessages(preferredMaxCount: Int?, focusPosition: Double, completion:(_ didAdjust: Bool) -> Void) {
        let didAdjust = self.slidingWindow.adjustWindow(focusPosition: focusPosition,
                                                        maxWindowSize: preferredMaxCount ?? self.preferredMaxWindowSize)
        completion(didAdjust)
    }

    func updateMessageStatus(_ message: UIMessageModelProtocol, _ error: Swift.Error?) {
        let status: MessageStatus

        if let error = error {
            status = .failed
            Log.error(error, message: "Unable to send message")
        }
        else {
            status = .sent
        }

        if message.status != status {
            DispatchQueue.main.async {
                message.status = status
                self.delegate?.chatDataSourceDidUpdate(self)
            }
        }
    }
}
