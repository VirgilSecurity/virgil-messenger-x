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

public protocol DemoMessageModelProtocol: MessageModelProtocol {
    var status: MessageStatus { get set }
}

public class MessageSender {
    public var onMessageChanged: ((_ message: DemoMessageModelProtocol) -> ())?

    public func sendMessages(_ messages: [DemoMessageModelProtocol]) {
        for message in messages {
            self.sendMessage(message)
        }
    }

    public func sendMessage(_ message: DemoMessageModelProtocol) {
        switch message {
        case is DemoTextMessageModel:
            let textMessage = message as! DemoTextMessageModel

            var text = textMessage.body
            if CoreDataHelper.sharedInstance.currentChannel?.type == ChannelType.group.rawValue {
                text = "\(TwilioHelper.sharedInstance.username): \(textMessage.body)"
            }
            if let encrypted = VirgilHelper.sharedInstance.encrypt(text) {
                self.messageStatus(ciphertext: encrypted, message: textMessage)
            }
        default:
            Log.error("Unknown message model")
        }
    }

    private func messageStatus(ciphertext: String, message: DemoTextMessageModel) {
        switch message.status {
        case .success:
            break
        case .failed:
            self.updateMessage(message, status: .sending)
            self.messageStatus(ciphertext: ciphertext, message: message)
        case .sending:
            if let messages = TwilioHelper.sharedInstance.currentChannel.messages {
                let options = TCHMessageOptions().withBody(ciphertext)
                Log.debug("sending \(ciphertext)")
                messages.sendMessage(with: options) { result, msg in
                    if result.isSuccessful() {
                        self.updateMessage(message, status: .success)
                        CoreDataHelper.sharedInstance.createTextMessage(withBody: message.body, isIncoming: false,
                                                                        date: message.date)
                    } else {
                        Log.error("error sending: Twilio cause")
                        self.updateMessage(message, status: .failed)
                    }
                }
            } else {
                Log.error("can't get channel messages")
            }
        }
    }

    private func updateMessage(_ message: DemoMessageModelProtocol, status: MessageStatus) {
        if message.status != status {
            message.status = status
            self.notifyMessageChanged(message)
        }
    }

    private func notifyMessageChanged(_ message: DemoMessageModelProtocol) {
        DispatchQueue.main.async {
             self.onMessageChanged?(message)
        }
    }
}
