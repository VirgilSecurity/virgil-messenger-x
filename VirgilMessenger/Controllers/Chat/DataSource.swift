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

    init(pageSize: Int) {
        self.slidingWindow = SlidingDataSource(pageSize: pageSize)
        self.pageSize = pageSize
        NotificationCenter.default.addObserver(self, selector: #selector(DataSource.processMessage(notification:)), name: Notification.Name(rawValue: TwilioHelper.Notifications.MessageAddedToSelectedChannel.rawValue), object: nil)

        self.getLastMessages()
    }

    private func getLastMessages() {
        let messagesCore: [DemoMessageModelProtocol] = self.getCoreDataLastMessages()
        //self.getTwilioLastMessages(coreMessagesCount: messagesCore.count)
    }

    @objc private func processMessage(notification: Notification) {
        Log.debug("processing message")
        guard  let userInfo = notification.userInfo,
            let message = userInfo[TwilioHelper.NotificationKeys.Message.rawValue] as? TCHMessage,
            let coreDataChannel = CoreDataHelper.sharedInstance.currentChannel,
            let messageDate = message.dateUpdatedAsDate else {
            return
        }
        guard let card = VirgilHelper.sharedInstance.channelCard  else {
            Log.error("channel card not found")
            return
        }
        guard let secureChat = VirgilHelper.sharedInstance.secureChat else {
            Log.error("nil secure Chat")
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
                    let session = try? secureChat.loadUpSession(withParticipantWithCard: card,
                                                                message: encryptedString),
                    let decryptedString = try? session.decrypt(encryptedString),
                    let decryptedData = Data(base64Encoded: decryptedString),
                    let image = UIImage(data: decryptedData) else {
                        Log.error("decryption process of media failed")
                        return
                }
                CoreDataHelper.sharedInstance.createMediaMessage(forChannel: coreDataChannel, withData: decryptedData,
                                                                     isIncoming: true, date: messageDate)
                let model = MessageFactory.createMessageModel("\(self.nextMessageId)", isIncoming: isIncoming,
                                                              type: PhotoMessageModel<MessageModel>.chatItemType,
                                                              status: .success, date: messageDate)
                let decryptedMessage = DemoPhotoMessageModel(messageModel: model, imageSize: image.size, image: image)

                self.slidingWindow.insertItem(decryptedMessage, position: .bottom)
                self.nextMessageId += 1
                self.delegate?.chatDataSourceDidUpdate(self)
            }
        } else if let messageBody = message.body {
            do {
                let session = try secureChat.loadUpSession(withParticipantWithCard: card, message: messageBody)
                let decryptedMessageBody = try session.decrypt(messageBody)
                Log.debug("Receiving " + decryptedMessageBody)

                let model = MessageFactory.createMessageModel("\(self.nextMessageId)", isIncoming: isIncoming, type: TextMessageModel<MessageModel>.chatItemType, status: .success, date: messageDate)
                let decryptedMessage = DemoTextMessageModel(messageModel: model, text: decryptedMessageBody)

                CoreDataHelper.sharedInstance.createTextMessage(withBody: decryptedMessage.body, isIncoming: true, date: messageDate)

                self.slidingWindow.insertItem(decryptedMessage, position: .bottom)
                self.nextMessageId += 1
            } catch {
                Log.error("decryption process failed")
            }
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

extension DataSource {
    private func getCoreDataLastMessages() -> [DemoMessageModelProtocol] {
        var result: [DemoMessageModelProtocol] = []

        guard let channel = CoreDataHelper.sharedInstance.currentChannel,
            let messages = channel.message else {
                Log.error("Can't get last messages: channel not found in Core Data")
                return result
        }

        for message in messages {
            guard let message = message as? Message,
                let messageDate = message.date
                else {
                    Log.error("retriving message from Core Data failed")
                    return result
            }

            let decryptedMessage: DemoMessageModelProtocol
            if let messageMedia = message.media {
                if let decryptedMedia = try? VirgilHelper.sharedInstance.decrypt(data: messageMedia),
                    let image = UIImage(data: decryptedMedia) {

                    let model = MessageFactory.createMessageModel("\(self.nextMessageId)", isIncoming: message.isIncoming,
                                                                  type: PhotoMessageModel<MessageModel>.chatItemType,
                                                                  status: .success, date: messageDate)
                    decryptedMessage = DemoPhotoMessageModel(messageModel: model, imageSize: image.size, image: image)
                } else {
                    Log.error("decrypting media message failed")
                    let model = MessageFactory.createMessageModel("\(self.nextMessageId)", isIncoming: message.isIncoming,
                                                                  type: TextMessageModel<MessageModel>.chatItemType,
                                                                  status: .failed, date: messageDate)
                    decryptedMessage =  DemoTextMessageModel(messageModel: model, text: "Failed to decrypt image")
                }
            } else if let messageBody = message.body {
                let decryptedBody = try? VirgilHelper.sharedInstance.decrypt(text: messageBody)

                let model = MessageFactory.createMessageModel("\(self.nextMessageId)", isIncoming: message.isIncoming,
                                                              type: TextMessageModel<MessageModel>.chatItemType,
                                                              status: .success, date: messageDate)
                decryptedMessage = DemoTextMessageModel(messageModel: model, text: decryptedBody ?? "Error decrypting message")
            } else {
                let model = MessageFactory.createMessageModel("\(self.nextMessageId)", isIncoming: message.isIncoming,
                                                              type: TextMessageModel<MessageModel>.chatItemType,
                                                              status: .failed, date: messageDate)
                decryptedMessage =  DemoTextMessageModel(messageModel: model, text: "Corrupted Message")
            }
            self.slidingWindow.insertItem(decryptedMessage, position: .bottom)
            self.nextMessageId += 1

            result.append(decryptedMessage)
            if message.isIncoming == false {
                result = []
                continue
            }
        }

        return result
    }

    private func getTwilioLastMessages(coreMessagesCount: Int) {
        guard let card = VirgilHelper.sharedInstance.channelCard else {
            Log.error("channel card not found")
            return
        }
        guard let secureChat = VirgilHelper.sharedInstance.secureChat else {
            Log.error("nil secure Chat")
            return
        }
        guard let messages = TwilioHelper.sharedInstance.currentChannel.messages else {
            Log.error("nil messages in selected channel")
            return
        }
        Log.debug("channel card id: \(card.identity)")
        Log.debug("selected channel with attributes: \(TwilioHelper.sharedInstance.currentChannel.attributes() ?? ["no attributes" : ""])")

        TwilioHelper.sharedInstance.currentChannel.getMessagesCount { result, count in
            guard result.isSuccessful() else {
                Log.error("Can't get Twilio messages count")
                return
            }
            let needToLoadCount = Int(count) - coreMessagesCount

            if needToLoadCount > 0 {
                messages.getLastWithCount(UInt(needToLoadCount), completion: { result, messages in
                    guard let messages = messages else {
                        Log.error("Twilio can't get last messages")
                        return
                    }
                    for message in messages {
                        guard let messageDate = message.dateUpdatedAsDate else {
                            Log.error("wrong message atributes")
                            continue
                        }
                        let isIncoming = message.author == TwilioHelper.sharedInstance.username ? false : true

                        if message.hasMedia() {
                            TwilioHelper.sharedInstance.getMedia(from: message) { encryptedData in
                                guard let encryptedData = encryptedData,
                                    let encryptedString = String(data: encryptedData, encoding: .utf8),
                                    let session = try? secureChat.loadUpSession(withParticipantWithCard: card,
                                                                                message: encryptedString),
                                    let decryptedString = try? session.decrypt(encryptedString),
                                    let decryptedData = Data(base64Encoded: decryptedString),
                                    let image = UIImage(data: decryptedData) else {
                                        Log.error("decryption of Media failed")
                                        return
                                }

                                let photoMessageModel = MessageFactory.createPhotoMessageModel("\(self.nextMessageId)", image: image,
                                                                                               size: image.size, isIncoming: isIncoming,
                                                                                               status: .success, date: messageDate)
                                self.slidingWindow.insertItem(photoMessageModel, position: .bottom)
                                self.nextMessageId += 1

                                CoreDataHelper.sharedInstance.createMediaMessage(withData: decryptedData,
                                                                                 isIncoming: isIncoming,
                                                                                 date: messageDate)
                                self.delegate?.chatDataSourceDidUpdate(self, updateType: .reload)
                            }
                        } else if let messageBody = message.body {
                            do {
                                let session = try secureChat.loadUpSession(withParticipantWithCard: card, message: messageBody)
                                let decryptedMessageBody = try session.decrypt(messageBody)

                                let textMessageModel = MessageFactory.createTextMessageModel("\(self.nextMessageId)", text: decryptedMessageBody,
                                                                                             isIncoming: isIncoming, status: .success, date: messageDate)
                                self.slidingWindow.insertItem(textMessageModel, position: .bottom)
                                self.nextMessageId += 1

                                CoreDataHelper.sharedInstance.createTextMessage(withBody: decryptedMessageBody, isIncoming: isIncoming, date: messageDate)
                            } catch {
                                Log.error("decryption process failed: \(error.localizedDescription)")
                            }
                        }
                    }
                    self.delegate?.chatDataSourceDidUpdate(self, updateType: .reload)
                })
            }
        }
    }
}
