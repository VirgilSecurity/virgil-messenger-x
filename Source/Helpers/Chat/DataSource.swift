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
    public var nextMessageId: Int = 0

    private let preferredMaxWindowSize = 500
    private var slidingWindow: SlidingDataSource<ChatItemProtocol>!

    private var count: Int {
        return self.channel.visibleMessages.count
    }

    init(channel: Storage.Channel) {
        self.channel = channel

        self.slidingWindow = SlidingDataSource(count: count) { [weak self] (messageNumber, messages) -> ChatItemProtocol in
            self?.nextMessageId += 1
            let id = self?.nextMessageId ?? 0

            guard self != nil,
                let message = messages[safe: messageNumber] else {
                    return UITextMessageModel.corruptedModel(uid: id)
            }

            return Storage.exportAsUIModel(message: message, with: id)
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

    @objc private func process(message: Storage.Message) {
        self.nextMessageId += 1
        let uiModel = Storage.exportAsUIModel(message: message, with: self.nextMessageId)

        DispatchQueue.main.async {
            self.slidingWindow.insertItem(uiModel, position: .bottom)
            self.delegate?.chatDataSourceDidUpdate(self)
        }
    }

    lazy var messageSender: MessageSender = {
        return MessageSender()
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

        let message = NetworkMessage.Text(body: text)

        self.slidingWindow.insertItem(uiModel, position: .bottom)
        self.delegate?.chatDataSourceDidUpdate(self)

        self.messageSender.send(text: message, date: uiModel.date, channel: self.channel) { (error) in
            self.updateMessageStatus(uiModel, error)
        }
    }

    func addPhotoMessage(_ image: UIImage) {
        self.nextMessageId += 1
        let id = self.nextMessageId

        // Put image to the chat view
        let uiModel = UIPhotoMessageModel(uid: id,
                                          image: image,
                                          isIncoming: false,
                                          status: .success,
                                          state: .uploading,
                                          date: Date())

        self.slidingWindow.insertItem(uiModel, position: .bottom)
        self.delegate?.chatDataSourceDidUpdate(self)

        // FIXME: Move out from the main thread
        guard let imageData = image.jpegData(compressionQuality: 0.0),
            let thumbnailData = image.resized(to: 10)?.jpegData(compressionQuality: 1.0) else {
                self.updateMessageStatus(uiModel, UserFriendlyError.imageCompressionFailed)
                return
        }

        let identifier = Virgil.shared.crypto.computeHash(for: imageData)
            .subdata(in: 0..<32)
            .hexEncodedString()


        self.messageSender.upload(data: imageData, identifier: identifier, channel: self.channel, loadDelegate: uiModel) { (url, error) in
            guard let url = url else {
                assert(error != nil)
                self.updateMessageStatus(uiModel, error)
                return
            }

            let photo = NetworkMessage.Photo(identifier: identifier, url: url)

            self.messageSender.send(photo: photo, image: imageData, thumbnail: thumbnailData, date: uiModel.date, channel: self.channel) { (error) in
                self.updateMessageStatus(uiModel, error)
            }
        }
    }

    func addVoiceMessage(_ audioUrl: URL, duration: TimeInterval) {
        self.nextMessageId += 1
        let id = self.nextMessageId

        let uiModel = UIAudioMessageModel(uid: id,
                                          audioUrl: audioUrl,
                                          duration: duration,
                                          isIncoming: false,
                                          status: .success,
                                          state: .uploading,
                                          date: Date())

        self.slidingWindow.insertItem(uiModel, position: .bottom)
        self.delegate?.chatDataSourceDidUpdate(self)

        // TODO: optimize. Do not fetch data to memrory, use streams
        let voiceData: Data
        do {
            voiceData = try Data(contentsOf: uiModel.audioUrl)
        }
        catch {
            self.updateMessageStatus(uiModel, error)
            return
        }

        self.messageSender.upload(data: voiceData, identifier: uiModel.identifier, channel: self.channel, loadDelegate: uiModel) { (url, error) in
            guard let url = url else {
                assert(error != nil)
                self.updateMessageStatus(uiModel, error)
                return
            }

            let voice = NetworkMessage.Voice(identifier: uiModel.identifier, duration: uiModel.duration, url: url)

            self.messageSender.send(voice: voice, date: uiModel.date, channel: self.channel) { (error) in
                self.updateMessageStatus(uiModel, error)
            }
        }
    }

    func adjustNumberOfMessages(preferredMaxCount: Int?, focusPosition: Double, completion:(_ didAdjust: Bool) -> ()) {
        let didAdjust = self.slidingWindow.adjustWindow(focusPosition: focusPosition,
                                                        maxWindowSize: preferredMaxCount ?? self.preferredMaxWindowSize)
        completion(didAdjust)
    }

    func updateMessageStatus(_ message: UIMessageModelProtocol, _ error: Error?) {
        let status: MessageStatus

        if let error = error {
            status = .failed
            Log.error(error, message: "Unable to send message")
        }
        else {
            status = .success
        }

        if message.status != status {
            message.status = status
            self.delegate?.chatDataSourceDidUpdate(self)
        }
    }
}
