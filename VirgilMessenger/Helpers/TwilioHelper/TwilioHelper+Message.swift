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
                    return
            }
            channel.lastMessagesDate = date

            if message.hasMedia() {
                switch message.mediaType {
                case MediaType.photo.rawValue:
                    channel.lastMessagesBody = CoreDataHelper.sharedInstance.lastMessageIdentifier[CoreDataHelper.MessageType.photo.rawValue] ?? "corrupted type"
                case MediaType.audio.rawValue:
                    channel.lastMessagesBody = CoreDataHelper.sharedInstance.lastMessageIdentifier[CoreDataHelper.MessageType.audio.rawValue] ?? "corrupted type"
                default:
                    Log.error("Missing or unknown media type")
                }
            } else if let body = message.body {
                if message.author != TwilioHelper.sharedInstance.username {
                    guard let decryptedMessageBody = VirgilHelper.sharedInstance.decryptPFS(cardString: channel.card,
                                                                                            encrypted: body) else {
                        return
                    }
                    channel.lastMessagesBody = decryptedMessageBody
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

                        if message.hasMedia() {
                            TwilioHelper.sharedInstance.getMediaSync(from: message) { encryptedData in
                                guard let encryptedData = encryptedData,
                                    let encryptedString = String(data: encryptedData, encoding: .utf8),
                                    let decryptedString = VirgilHelper.sharedInstance.decryptPFS(encrypted: encryptedString),
                                    let decryptedData = Data(base64Encoded: decryptedString) else {
                                        Log.error("decryption of media message failed")
                                        makeCorruptedMessage()
                                        return
                                }

                                switch message.mediaType {
                                case MediaType.photo.rawValue:
                                    CoreDataHelper.sharedInstance.createMediaMessage(with: decryptedData, isIncoming: isIncoming,
                                                                                     date: messageDate, type: .photo)
                                case MediaType.audio.rawValue:
                                    CoreDataHelper.sharedInstance.createMediaMessage(with: decryptedData, isIncoming: isIncoming,
                                                                                     date: messageDate, type: .audio)
                                default:
                                    Log.error("Missing or unknown mediaType")
                                    makeCorruptedMessage()
                                    return
                                }
                            }
                        } else if let messageBody = message.body {
                            guard let decryptedMessageBody = VirgilHelper.sharedInstance.decryptPFS(encrypted: messageBody) else {
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

    func decryptFirstMessage(of messages: TCHMessages, channel: Channel, saved: Int,
                             completion: @escaping (TCHMessage?, String?, Data?, String?, Date?) -> ()) {
        messages.getBefore(UInt(saved), withCount: 1) { result, oneMessages in
            guard let oneMessages = oneMessages,
                let message = oneMessages.first,
                let messageDate = message.dateUpdatedAsDate,
                message.author != TwilioHelper.sharedInstance.username else {
                    completion(nil, nil, nil, nil, nil)
                    return
            }
            if message.hasMedia(), message.mediaType != nil {
                self.getMedia(from: message) { encryptedData in
                    guard let encryptedData = encryptedData,
                        let encryptedString = String(data: encryptedData, encoding: .utf8),
                        let decryptedString = VirgilHelper.sharedInstance.decryptPFS(cardString: channel.card,
                                                                                     encrypted: encryptedString),
                        let decryptedData = Data(base64Encoded: decryptedString) else {
                            Log.error("decryption process of first message failed")
                            completion(nil, nil, nil, nil, nil)
                            return
                    }
                    completion(message, nil, decryptedData, message.mediaType, messageDate)
                }
            } else if let messageBody = message.body {
                guard let decryptedMessageBody = VirgilHelper.sharedInstance.decryptPFS(cardString: channel.card,
                                                                                        encrypted: messageBody) else {
                    completion(nil, nil, nil, nil, nil)
                    return
                }

                channel.lastMessagesBody = decryptedMessageBody
                channel.lastMessagesDate = messageDate

                completion(message, decryptedMessageBody, nil, nil, messageDate)
            } else {
                Log.error("Empty first message")
                completion(nil, nil, nil, nil, nil)
            }
        }
    }

    func getMedia(from message: TCHMessage, completion: @escaping (Data?) -> ()) {
        self.queue.async {
            let group = DispatchGroup()
            let tempFilename = (NSTemporaryDirectory() as NSString).appendingPathComponent(message.mediaFilename ?? "file.dat")
            let outputStream = OutputStream(toFileAtPath: tempFilename, append: false)

            if let outputStream = outputStream {
                Log.debug("trying to get media")
                group.enter()
                message.getMediaWith(outputStream,
                                     onStarted: {
                                        Log.debug("Media upload started")
                },
                                     onProgress: { (bytes) in
                                        Log.debug("Media upload progress: \(bytes)")
                },
                                     onCompleted: { (mediaSid) in
                                        Log.debug("Media upload completed")
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
                    defer { group.leave() }
                }
            } else {
                Log.error("outputStream failed")
            }
            group.wait()
        }
    }

    func getMediaSync(from message: TCHMessage, completion: @escaping (Data?) -> ()) {
        let group = DispatchGroup()
        let tempFilename = (NSTemporaryDirectory() as NSString).appendingPathComponent(message.mediaFilename ?? "file.dat")
        let outputStream = OutputStream(toFileAtPath: tempFilename, append: false)

        if let outputStream = outputStream {
            Log.debug("trying to get media")
            group.enter()
            message.getMediaWith(outputStream,
                                 onStarted: {
                                    Log.debug("Media upload started")
            },
                                 onProgress: { (bytes) in
                                    Log.debug("Media upload progress: \(bytes)")
            },
                                 onCompleted: { (mediaSid) in
                                    Log.debug("Media upload completed")
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
                defer { group.leave() }
            }
        } else {
            Log.error("outputStream failed")
        }
        group.wait()
    }
}
