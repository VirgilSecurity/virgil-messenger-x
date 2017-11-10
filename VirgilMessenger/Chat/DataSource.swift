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
        NotificationCenter.default.addObserver(self, selector: #selector(DataSource.processMessage(notification:)), name: Notification.Name(rawValue: TwilioHelper.Notifications.MessageAdded.rawValue), object: nil)
        
        self.getLastMessages()
    }
    
    private func getLastMessages() {
        guard let channel = CoreDataHelper.sharedInstance.selectedChannel else {
            Log.error("Can't get last messages: channel not found in Core Data")
            return
        }
        let messages = channel.message!
        var tmp_messages: [DemoTextMessageModel] = []
        
        for message in messages {
            let message = message as! Message
            let isIncoming = message.isIncoming
            
            let model = createMessageModel("\(self.nextMessageId)", isIncoming: isIncoming, type: TextMessageModel<MessageModel>.chatItemType, status: .success)
            let decryptedMessage = DemoTextMessageModel(messageModel: model, text: message.body!)
            
            self.slidingWindow.insertItem(decryptedMessage, position: .bottom)
            self.nextMessageId += 1
            
            tmp_messages.append(decryptedMessage)
            if isIncoming == false {
                tmp_messages = []
            }
        }
        
        var new_tmp_messages: [DemoTextMessageModel] = []
        
        let cards = VirgilHelper.sharedInstance.channelsCards.filter { $0.identity == TwilioHelper.sharedInstance.getCompanion(ofChannel: TwilioHelper.sharedInstance.selectedChannel) }
        guard let card = cards.first else {
            Log.error("channel card not found")
            return
        }
        
        Log.debug("channel card id: \(card.identity)")
        Log.debug("selected channel with attributes: \(TwilioHelper.sharedInstance.selectedChannel.attributes()!)")
        
        TwilioHelper.sharedInstance.getLastMessages(count: pageSize) { messages in
            for message in messages {
                if message?.isIncoming == false {
                    new_tmp_messages = []
                    continue
                }
                do {
                    let session = try VirgilHelper.sharedInstance.secureChat?.loadUpSession(
                        withParticipantWithCard: card, message: message!.body)
                    Log.debug("session loaded")
                    
                    let plaintext = try session?.decrypt(message!.body)
                    Log.debug("encrypted")
                    
                    let model = createMessageModel("\(self.nextMessageId)", isIncoming: message!.isIncoming, type: TextMessageModel<MessageModel>.chatItemType, status: .success)
                    let decryptedMessage = DemoTextMessageModel(messageModel: model, text: plaintext!)
                    
                    new_tmp_messages.append(decryptedMessage)
                } catch {
                    Log.error("decryption process failed: \(error.localizedDescription)\nMessage: \(message!.body)")
                }
            }
            
            if (tmp_messages.count > new_tmp_messages.count) {
                Log.error("saved messages count > loaded: \(tmp_messages.count) > \(new_tmp_messages.count)")
            } else {
                for i in tmp_messages.count..<new_tmp_messages.count {
                    
                    CoreDataHelper.sharedInstance.createMessage(withBody: new_tmp_messages[i].body, isIncoming: new_tmp_messages[i].isIncoming)
                    
                    self.slidingWindow.insertItem(new_tmp_messages[i], position: .bottom)
                    self.nextMessageId += 1
                }
            }
            self.delegate?.chatDataSourceDidUpdate(self, updateType: .reload)
        }
    }
    
    @objc private func processMessage(notification: Notification) {
        Log.debug("processing message")
        TwilioHelper.sharedInstance.getLastMessages(count: 1) { messages in
            guard let message = messages.first else {
                Log.error("Twilio gave no message")
                return
            }
            
            let cards = VirgilHelper.sharedInstance.channelsCards.filter { $0.identity == TwilioHelper.sharedInstance.getCompanion(ofChannel: TwilioHelper.sharedInstance.selectedChannel) }
            guard let card = cards.first else {
                Log.error("channel card not found")
                return
            }
            do {
                let session = try VirgilHelper.sharedInstance.secureChat?.loadUpSession(
                    withParticipantWithCard: card, message: message!.body)
                let plaintext = try session?.decrypt(message!.body)
                Log.debug("Receiving " + plaintext!)
                
                let model = createMessageModel("\(self.nextMessageId)", isIncoming: true, type: TextMessageModel<MessageModel>.chatItemType, status: .success)
                let decryptedMessage = DemoTextMessageModel(messageModel: model, text: plaintext!)
                
                CoreDataHelper.sharedInstance.createMessage(withBody: decryptedMessage.body, isIncoming: true)
                
                self.slidingWindow.insertItem(decryptedMessage, position: .bottom)
                self.nextMessageId += 1
                self.delegate?.chatDataSourceDidUpdate(self, updateType: .pagination)
            } catch {
                Log.error("decryption process failed")
            }
        }
    }

    lazy var messageSender: MessageSender = {
        let sender = MessageSender()
        sender.onMessageChanged = { [weak self] (message) in
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
        let message = createTextMessageModel(uid, text: text, isIncoming: false, status: .sending)
        self.messageSender.sendMessage(message)
        self.slidingWindow.insertItem(message, position: .bottom)
        self.delegate?.chatDataSourceDidUpdate(self)
    }

    func adjustNumberOfMessages(preferredMaxCount: Int?, focusPosition: Double, completion:(_ didAdjust: Bool) -> Void) {
        let didAdjust = self.slidingWindow.adjustWindow(focusPosition: focusPosition, maxWindowSize: preferredMaxCount ?? self.preferredMaxWindowSize)
        completion(didAdjust)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
