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
import VirgilSDKPFS

public protocol DemoMessageModelProtocol: MessageModelProtocol {
    var status: MessageStatus { get set }
}

public class MessageSender {

    public var onMessageChanged: ((_ message: DemoMessageModelProtocol) -> Void)?

    public func sendMessages(_ messages: [DemoMessageModelProtocol]) {
        for message in messages {
            self.sendMessage(message)
        }
    }

    public func sendMessage(_ message: DemoMessageModelProtocol) {
        let cards = VirgilHelper.sharedInstance.channelsCards.filter { $0.identity == TwilioHelper.sharedInstance.getCompanion(ofChannel: TwilioHelper.sharedInstance.selectedChannel) }
        guard let card = cards.first else {
            Log.error("channel card not found")
            self.updateMessage(message, status: .failed)
            return
        }
        Log.debug("sending to " + card.identity)
        guard let session = VirgilHelper.sharedInstance.secureChat?.activeSession(
            withParticipantWithCardId: card.identifier) else {
                VirgilHelper.sharedInstance.secureChat?.startNewSession(
                    withRecipientWithCard: card) { session, error in
                            
                    guard error == nil, let session = session else {
                        Log.error("creating session failed: " + error!.localizedDescription)
                         self.updateMessage(message, status: .failed)
                        return
                    }
                        
                    self.sendMessage(usingSession: session, message: message)
                }
                return
            }
        self.sendMessage(usingSession: session, message: message)
    }
    
    private func sendMessage(usingSession session: SecureSession, message: DemoMessageModelProtocol) {
        let msg = message as! DemoTextMessageModel
        do {
            let ciphertext = try session.encrypt(msg.body)
            self.MessageStatus(ciphertext: ciphertext, message: message)
        }
        catch {
            Log.error("Error trying to encrypt message")
             self.updateMessage(message, status: .failed)
            return
        }
    }

    private func MessageStatus(ciphertext: String, message: DemoMessageModelProtocol) {
        switch message.status {
        case .success:
            break
        case .failed:
            self.updateMessage(message, status: .sending)
            self.MessageStatus(ciphertext: ciphertext, message: message)
        case .sending:
            if let messages = TwilioHelper.sharedInstance.selectedChannel.messages {
                let options = TCHMessageOptions().withBody(ciphertext)
                Log.debug("sending \(ciphertext)")
                messages.sendMessage(with: options) { result, msg in
                    if result.isSuccessful() {
                        let msg = message as! DemoTextMessageModel
                        
                        CoreDataHelper.sharedInstance.createMessage(withBody: msg.body, isIncoming: false)
                        
                        self.updateMessage(message, status: .success)
                        return
                    } else {
                        Log.error("error sending: Twilio cause")
                        self.updateMessage(message, status: .failed)
                        return
                    }
                }
            }
            else {
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
        self.onMessageChanged?(message)
    }
}
