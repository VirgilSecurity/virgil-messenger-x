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

        self.getTwilioLastMessages { messagesTwilio in
            Log.debug("\(messagesCore.count)")
            Log.debug("\(messagesTwilio.count)")
            if (messagesCore.count > messagesTwilio.count) {
                Log.error("saved messages count > loaded: \(messagesCore.count) > \(messagesTwilio.count)")
            } else {
                for i in messagesCore.count..<messagesTwilio.count {
                    if let message = messagesTwilio[i] as? DemoTextMessageModel {
                        CoreDataHelper.sharedInstance.createTextMessage(withBody: message.body, isIncoming: message.isIncoming, date: message.date)
                    } else if let message = messagesTwilio[i] as? DemoPhotoMessageModel,
                            let data = UIImageJPEGRepresentation(message.image, 0.0) {
                        CoreDataHelper.sharedInstance.createMediaMessage(withData: data, isIncoming: message.isIncoming, date: message.date)
                    }
                    self.slidingWindow.insertItem(messagesTwilio[i], position: .bottom)
                    self.nextMessageId += 1
                }
            }
            self.delegate?.chatDataSourceDidUpdate(self, updateType: .reload)
        }
    }

    @objc private func processMessage(notification: Notification) {
        Log.debug("processing message")
        TwilioHelper.sharedInstance.getLastMessages(count: 1) { messages in
            guard  let firstMessage = messages.first, let message = firstMessage else {
                Log.error("Twilio gave no message")
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
            do {
                if let message = message as? DemoEncryptedPhotoMessageModel {
                    guard let encryptedString = String(data: message.encryptedData, encoding: .utf8),
                        let session = try? secureChat.loadUpSession(withParticipantWithCard: card,
                                                                    message: encryptedString),
                        let decryptedString = try? session.decrypt(encryptedString),
                        let decryptedData = Data(base64Encoded: decryptedString),
                        let image = UIImage(data: decryptedData) else {
                            Log.error("decryption process of media failed")
                            return
                    }

                    let model = MessageFactory.createMessageModel("\(self.nextMessageId)", isIncoming: message.isIncoming,
                                                                  type: PhotoMessageModel<MessageModel>.chatItemType,
                                                                  status: .success, date: message.date)
                    let decryptedMessage = DemoPhotoMessageModel(messageModel: model, imageSize: image.size, image: image)

                    CoreDataHelper.sharedInstance.createMediaMessage(withData: decryptedData, isIncoming: true, date: message.date)

                    self.slidingWindow.insertItem(decryptedMessage, position: .bottom)
                    self.nextMessageId += 1
                } else if let message = message as? DemoTextMessageModel {
                    let session = try secureChat.loadUpSession(withParticipantWithCard: card, message: message.body)
                    let decryptedMessageBody = try session.decrypt(message.body)
                    Log.debug("Receiving " + decryptedMessageBody)

                    let model = MessageFactory.createMessageModel("\(self.nextMessageId)", isIncoming: true, type: TextMessageModel<MessageModel>.chatItemType, status: .success, date: message.date)
                    let decryptedMessage = DemoTextMessageModel(messageModel: model, text: decryptedMessageBody)

                    CoreDataHelper.sharedInstance.createTextMessage(withBody: decryptedMessage.body, isIncoming: true, date: message.date)

                    self.slidingWindow.insertItem(decryptedMessage, position: .bottom)
                    self.nextMessageId += 1
                }
                self.delegate?.chatDataSourceDidUpdate(self)
            } catch {
                Log.error("decryption process failed")
            }
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

    private func getTwilioLastMessages(completion: @escaping ([DemoMessageModelProtocol]) -> ()) {
        var result: [DemoMessageModelProtocol] = []

        guard let card = VirgilHelper.sharedInstance.channelCard else {
            Log.error("channel card not found")
            return
        }

        Log.debug("channel card id: \(card.identity)")
        Log.debug("selected channel with attributes: \(TwilioHelper.sharedInstance.currentChannel.attributes() ?? ["no attributes" : ""])")

        TwilioHelper.sharedInstance.getLastMessages(count: pageSize) { messages in
            for message in messages {
                guard let message = message
                    else {
                        Log.error("retriving messages from Twilio failed")
                        completion(result)
                        return
                }
                if message.isIncoming == false {
                    result = []
                    continue
                }
                guard let secureChat = VirgilHelper.sharedInstance.secureChat else {
                    Log.error("nil secure Chat")
                    completion(result)
                    return
                }
                do {
                    if let message = message as? DemoTextMessageModel {
                        let session = try secureChat.loadUpSession(withParticipantWithCard: card, message: message.body)
                        let decryptedMessageBody = try session.decrypt(message.body)

                        let model = MessageFactory.createMessageModel("\(self.nextMessageId)", isIncoming: message.isIncoming,
                                                                      type: TextMessageModel<MessageModel>.chatItemType,
                                                                      status: .success, date: message.date)
                        let decryptedMessage = DemoTextMessageModel(messageModel: model, text: decryptedMessageBody)

                        result.append(decryptedMessage)
                    } else if let message = message as? DemoEncryptedPhotoMessageModel {
                        guard let encryptedString = String(data: message.encryptedData, encoding: .utf8),
                            let session = try? secureChat.loadUpSession(withParticipantWithCard: card,
                                                                        message: encryptedString),
                            let decryptedString = try? session.decrypt(encryptedString),
                            let decryptedData = Data(base64Encoded: decryptedString),
                            let image = UIImage(data: decryptedData) else {
                                Log.error("decryption process of media failed")
                                return
                        }

                        let model = MessageFactory.createMessageModel("\(self.nextMessageId)", isIncoming: message.isIncoming,
                                                                      type: PhotoMessageModel<MessageModel>.chatItemType,
                                                                      status: .success, date: message.date)
                        let decryptedMessage = DemoPhotoMessageModel(messageModel: model, imageSize: image.size, image: image)

                        result.append(decryptedMessage)
                    }
                } catch {
                    Log.error("decryption process failed: \(error.localizedDescription)")
                    let model = MessageFactory.createMessageModel("\(self.nextMessageId)", isIncoming: message.isIncoming,
                                                                  type: TextMessageModel<MessageModel>.chatItemType,
                                                                  status: .success, date: message.date)
                    let decryptedMessage = DemoTextMessageModel(messageModel: model, text: "Error decrypting message")
                    result.append(decryptedMessage)
                }
            }
            completion(result)
        }
    }
}
