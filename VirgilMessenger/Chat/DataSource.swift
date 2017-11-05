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

class DataSource: ChatDataSourceProtocol {
    var nextMessageId: Int = 0
    let preferredMaxWindowSize = 500
    
    var slidingWindow: SlidingDataSource<ChatItemProtocol>!
    init(pageSize: Int) {
        
        self.slidingWindow = SlidingDataSource(pageSize: pageSize)
        
        //FIXME
        NotificationCenter.default.addObserver(forName:Notification.Name(rawValue: TwilioHelper.Notifications.MessageAdded.rawValue),
                    object:nil, queue:nil) {
                        notification in
                        TwilioHelper.sharedInstance.getLastMessages(count: 1) { messages in
                            for message in messages {
                                self.slidingWindow.insertItem(message!, position: .bottom)
                                self.nextMessageId += 1
                            }
                            self.delegate?.chatDataSourceDidUpdate(self, updateType: .pagination)
                        }
        }
        
        TwilioHelper.sharedInstance.getLastMessages(count: pageSize) { messages in
            for message in messages {
                self.slidingWindow.insertItem(message!, position: .bottom)
                self.nextMessageId += 1
            }
            self.delegate?.chatDataSourceDidUpdate(self, updateType: .reload)
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
