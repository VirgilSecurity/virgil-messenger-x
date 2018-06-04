//
//  TwilioHelper+Message.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 3/5/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import UIKit
import TwilioChatClient

extension TwilioHelper {
    func setLastMessage(of messages: TCHMessages, channel: Channel, completion: @escaping () -> ()) {
        messages.getLastWithCount(UInt(1)) { result, messages in
            guard result.isSuccessful(),
                let messages = messages,
                let message = messages.last,
                let date = message.dateUpdatedAsDate else {
                    Log.error("get last twilio message failed with: \(result.error?.localizedDescription ?? "unknown error")")
                    completion()
                    return
            }
            channel.lastMessagesDate = date

           if let body = message.body {
                if message.author != TwilioHelper.sharedInstance.username {
                    guard let decryptedBody = VirgilHelper.sharedInstance.decrypt(body) else {
                        completion()
                        return
                    }
                    channel.lastMessagesBody = decryptedBody
                }
            } else {
                Log.error("Empty twilio message")
            }

            completion()
        }
    }

    func updateMessages(count: Int, completion: @escaping (Int, Error?) -> ()) {
        guard let coreMessagesCount = CoreDataHelper.sharedInstance.currentChannel?.message?.count else {
            Log.error("Get CoreData messages count failed")
            DispatchQueue.main.async {
                completion(0, NSError())
            }
            return
        }

        let needToLoadCount = count - coreMessagesCount

        guard let messages = TwilioHelper.sharedInstance.currentChannel.messages else {
            Log.error("Twilio: nil messages in selected channel")
            DispatchQueue.main.async {
                completion(0, NSError())
            }
            return
        }

        if needToLoadCount > 0 {
            messages.getLastWithCount(UInt(needToLoadCount), completion: { result, messages in
                guard let messages = messages else {
                    Log.error("Twilio can't get last messages")
                    DispatchQueue.main.async {
                        completion(-1, NSError())
                    }
                    return
                }
                TwilioHelper.sharedInstance.queue.async {
                    for message in messages {
                        let isIncoming = message.author == TwilioHelper.sharedInstance.username ? false : true
                        guard let messageDate = message.dateUpdatedAsDate else {
                            Log.error("wrong message atributes")
                            CoreDataHelper.sharedInstance.createTextMessage(withBody: "Message corrupted",
                                                                            isIncoming: isIncoming, date: Date())
                            continue
                        }
                        let makeCorruptedMessage = {
                            CoreDataHelper.sharedInstance.createTextMessage(withBody: "Message encrypted",
                                                                            isIncoming: isIncoming, date: messageDate)
                        }
                        if let messageBody = message.body {
                            guard let decryptedMessageBody = VirgilHelper.sharedInstance.decrypt(messageBody) else {
                                makeCorruptedMessage()
                                continue
                            }
                            CoreDataHelper.sharedInstance.createTextMessage(withBody: decryptedMessageBody,
                                                                            isIncoming: isIncoming, date: messageDate)
                        } else {
                            Log.error("Corrupted Message")
                            makeCorruptedMessage()
                        }
                    }
                    DispatchQueue.main.async {
                        completion(needToLoadCount, nil)
                    }
                }
            })
        } else {
            DispatchQueue.main.async {
                completion(0, nil)
            }
        }
    }
}
