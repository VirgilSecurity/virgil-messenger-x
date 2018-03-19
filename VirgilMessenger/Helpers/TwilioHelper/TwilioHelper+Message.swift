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
    func setLastMessage(of messages: TCHMessages, channel: Channel, completion: @escaping () -> ()) {
        messages.getLastWithCount(UInt(1)) { result, messages in
            if let messages = messages,
                let message = messages.last,
                let messageBody = message.body,
                !message.hasMedia(),
                let messageDate = message.dateUpdatedAsDate,
                message.author != TwilioHelper.sharedInstance.username {
                    guard let decryptedMessageBody = VirgilHelper.sharedInstance.decryptPFS(cardString: channel.card,
                                                                                            encrypted: messageBody) else {
                        return
                    }
                    channel.lastMessagesBody = decryptedMessageBody
                    channel.lastMessagesDate = messageDate
            } else if messages?.last?.hasMedia() ?? false {
                channel.lastMessagesBody = "image.jpg"
                channel.lastMessagesDate = messages?.last?.dateUpdatedAsDate
            }

            completion()
        }
    }

    func decryptFirstMessage(of messages: TCHMessages, channel: Channel, saved: Int,
                             completion: @escaping (TCHMessage?, String?, Data?, Date?) -> ()) {
        messages.getBefore(UInt(saved), withCount: 1) { result, oneMessages in
            guard let oneMessages = oneMessages,
                let message = oneMessages.first,
                let messageDate = message.dateUpdatedAsDate,
                message.author != TwilioHelper.sharedInstance.username else {
                    completion(nil, nil, nil, nil)
                    return
            }
            if message.hasMedia() {
                self.getMedia(from: message) { encryptedData in
                    guard let encryptedData = encryptedData,
                        let encryptedString = String(data: encryptedData, encoding: .utf8),
                        let decryptedString = VirgilHelper.sharedInstance.decryptPFS(cardString: channel.card,
                                                                                     encrypted: encryptedString),
                        let decryptedData = Data(base64Encoded: decryptedString) else {
                            Log.error("decryption process of first message failed")
                            completion(nil, nil, nil, nil)
                            return
                    }
                    completion(message, nil, decryptedData, messageDate)
                }
            } else if let messageBody = message.body {
                guard let decryptedMessageBody = VirgilHelper.sharedInstance.decryptPFS(cardString: channel.card,
                                                                                        encrypted: messageBody) else {
                    return
                }

                channel.lastMessagesBody = decryptedMessageBody
                channel.lastMessagesDate = messageDate

                completion(message, decryptedMessageBody, nil, messageDate)
            } else {
                Log.error("Empty first message")
                 completion(nil, nil, nil, nil)
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
