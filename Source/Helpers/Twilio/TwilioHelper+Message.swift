//
//  TwilioHelper+Message.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 3/5/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import UIKit
import TwilioChatClient
import VirgilSDK

extension TwilioHelper {
    public func send(ciphertext: String, messages: TCHMessages, type: MessageType, identifier: String? = nil) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let options = TCHMessageOptions()
                options.withBody(ciphertext)

                let attributes = TwilioHelper.MessageAttributes(type: type, identifier: identifier)

                try options.withAttributes(attributes.export())

                Log.debug("Message type to send: \(type.rawValue)")

                self.send(with: options, to: messages).start(completion: completion)
            } catch {
                completion(nil, error)
            }
        }
    }

    private func send(with options: TCHMessageOptions, to messages: TCHMessages) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            messages.sendMessage(with: options) { result, _ in
                if let error = result.error {
                    Log.error("Message send failed: \(error)")
                    completion(nil, error)
                } else {
                    Log.debug("Message sent")
                    completion((), nil)
                }
            }
        }
    }

    public func delete(_ message: TCHMessage, from messages: TCHMessages) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            messages.remove(message) { result in
                if let error = result.error {
                    Log.debug("Service Message remove: \(error.description)")
                    completion(nil, error)
                } else {
                    completion((), nil)
                }
            }
        }
    }

    func makeGetMediaOperation(message: TCHMessage) -> CallbackOperation<Data> {
        return CallbackOperation { _, completion in
            let tempFilename = (NSTemporaryDirectory() as NSString).appendingPathComponent(message.mediaFilename ?? "file.dat")
            let outputStream = OutputStream(toFileAtPath: tempFilename, append: false)

            if let outputStream = outputStream {
                message.getMediaWith(outputStream,
                                     onStarted: { Log.debug("Media upload started") },
                                     onProgress: { Log.debug("Media upload progress: \($0)") },
                                     onCompleted: { _ in Log.debug("Media upload completed") })
                { result in
                    if let error = result.error {
                        completion(nil, error)
                        return
                    }

                    let url = URL(fileURLWithPath: tempFilename)

                    guard let data = try? Data(contentsOf: url) else {
                        completion(nil, NSError())
                        return
                    }

                    completion(data, nil)
                }
            } else {
                completion(nil, NSError())
            }
        }
    }
}
