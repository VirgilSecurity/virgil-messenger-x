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
    func makeGetMediaOperation(message: TCHMessage) -> CallbackOperation<Data> {
        return CallbackOperation<Data> { _, completion in
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
