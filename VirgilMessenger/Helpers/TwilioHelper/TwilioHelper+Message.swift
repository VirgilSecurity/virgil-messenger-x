//
//  TwilioHelper+Message.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 3/5/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation
import TwilioChatClient

extension TwilioHelper {
    func getLastMessages(count: Int, completion: @escaping ([DemoMessageModelProtocol?]) -> ()) {
        var ret = [DemoMessageModelProtocol]()
        guard let messages = self.currentChannel.messages else {
            Log.error("nil messages in selected channel")
            completion(ret)
            return
        }

        messages.getLastWithCount(UInt(count), completion: { result, messages in
            guard let messages = messages else {
                Log.error("Twilio can't get last messages")
                completion(ret)
                return
            }
            let group = DispatchGroup()
            for message in messages {
                guard let messageDate = message.dateUpdatedAsDate else {
                    Log.error("wrong message atributes")
                    completion(ret)
                    return
                }
                let isIncoming = message.author == self.username ? false : true

                if let messageBody = message.body {
                    let textMessageModel = MessageFactory.createTextMessageModel("\(ret.count)", text: messageBody, isIncoming: isIncoming,
                                                                                 status: .success, date: messageDate)
                    ret.append(textMessageModel)
                } else if message.hasMedia() {
                    group.enter()
                    self.getMedia(from: message) { encryptedData in
                        guard let encryptedData = encryptedData else {
                            completion(ret)
                            return
                        }
                        let encryptedPhotoMessageModel = MessageFactory.createEncryptedPhotoMessageModel("\(ret.count)", data: encryptedData,
                                                                                                         isIncoming: isIncoming, status: .success,
                                                                                                         date: messageDate)
                        ret.append(encryptedPhotoMessageModel)
                        group.leave()
                    }
                } else {
                    Log.error("Empty message")
                    completion(ret)
                    return
                }
            }
            group.wait()
            completion(ret)
        })
    }

    func setLastMessage(of messages: TCHMessages, channel: Channel, completion: @escaping () -> ()) {
        messages.getLastWithCount(UInt(1)) { result, messages in
            if  let messages = messages,
                let message = messages.last,
                let messageBody = message.body,
                let messageDate = message.dateUpdatedAsDate,
                message.author != TwilioHelper.sharedInstance.username,
                let stringCard = channel.card,
                let card = VirgilHelper.sharedInstance.buildCard(stringCard),
                let secureChat = VirgilHelper.sharedInstance.secureChat {
                do {
                    let session = try secureChat.loadUpSession(withParticipantWithCard: card, message: messageBody)
                    let decryptedMessageBody = try session.decrypt(messageBody)

                    channel.lastMessagesBody = decryptedMessageBody
                    channel.lastMessagesDate = messageDate
                } catch {
                    Log.error("decryption process failed: \(error.localizedDescription)")
                }
            }

            completion()
        }
    }

    func decryptFirstMessage(of messages: TCHMessages, channel: Channel, saved: Int, completion: @escaping (TCHMessage?, String?, Data?, Date?) -> ()) {
        messages.getBefore(UInt(saved), withCount: 1) { result, oneMessages in
            guard let oneMessages = oneMessages,
                let message = oneMessages.first,
                message.body != nil || message.hasMedia(),
                let messageDate = message.dateUpdatedAsDate,
                message.author != TwilioHelper.sharedInstance.username,
                let stringCard = channel.card,
                let card = VirgilHelper.sharedInstance.buildCard(stringCard),
                let secureChat = VirgilHelper.sharedInstance.secureChat else {
                    completion(nil, nil, nil, nil)
                    return
            }
            do {
                if let messageBody = message.body {
                    let session = try secureChat.loadUpSession(withParticipantWithCard: card, message: messageBody)
                    let decryptedMessageBody = try session.decrypt(messageBody)

                    channel.lastMessagesBody = decryptedMessageBody
                    channel.lastMessagesDate = messageDate

                    completion(message, decryptedMessageBody, nil, messageDate)
                } else if message.hasMedia() {
                    self.getMedia(from: message) { encryptedData in
                        guard let encryptedData = encryptedData,
                            let encryptedString = String(data: encryptedData, encoding: .utf8),
                            let session = try? secureChat.loadUpSession(withParticipantWithCard: card,
                                                                        message: encryptedString),
                            let decryptedString = try? session.decrypt(encryptedString),
                            let decryptedData = Data(base64Encoded: decryptedString) else {
                                Log.error("decryption process of first message failed")
                                completion(nil, nil, nil, nil)
                                return
                        }
                        completion(message, nil, decryptedData, messageDate)
                    }
                } else {
                    Log.error("Empty message")
                    completion(nil, nil, nil, nil)
                }
            } catch {
                Log.error("decryption process of first message failed: \(error.localizedDescription)")
                completion(nil, nil, nil, nil)
            }
        }
    }

    func getMedia(from message: TCHMessage, completion: @escaping (Data?) -> ()) {
        let tempFilename = (NSTemporaryDirectory() as NSString).appendingPathComponent(message.mediaFilename ?? "File.dat")
        let outputStream = OutputStream(toFileAtPath: tempFilename, append: false)
        if let outputStream = outputStream {
            message.getMediaWith(outputStream,
                                 onStarted: {

            },
                                 onProgress: { (bytes) in

            },
                                 onCompleted: { (mediaSid) in

            }) { result in
                guard result.isSuccessful() else {
                    Log.error("getting media message failed: \(result.error?.localizedDescription ?? "unknown error")")
                    completion(nil)
                    return
                }
                let url = URL(fileURLWithPath: tempFilename)
                guard let data = try? Data(contentsOf: url) else {
                    Log.error("reading media from temp directory failed")
                    completion(nil)
                    return
                }
                completion(data)
            }
        }
    }
}
