//
//  TCHMessage.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 6/20/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import TwilioChatClient
import VirgilSDK

extension TCHMessage {
    public enum Kind: String, Codable {
        case regular
        case service
    }

    struct Attributes: Codable {
        let type: Kind
        let identifier: String?

        static func `import`(_ json: [String: Any]) throws -> Attributes {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])

            return try JSONDecoder().decode(Attributes.self, from: data)
        }

        func export() throws -> [String: Any] {
            let data = try JSONEncoder().encode(self)

            guard let result = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw TwilioHelper.Error.invalidMessage
            }

            return result
        }
    }
}

extension TCHMessage {
    func getAttributes() throws -> Attributes {
        guard let rawAttributes = self.attributes() else {
            throw TwilioHelper.Error.invalidMessage
        }

        return try Attributes.import(rawAttributes)
    }

    func getDate() throws -> Date {
        guard let date = self.dateUpdatedAsDate else {
            throw TwilioHelper.Error.invalidMessage
        }

        return date
    }

    func getIndex() throws -> NSNumber {
        guard let index = self.index else {
            throw TwilioHelper.Error.invalidMessage
        }

        return index
    }

    func getAuthor() throws -> String {
        guard let author = self.author else {
            throw TwilioHelper.Error.invalidMessage
        }

        return author
    }

    func getMedia() -> CallbackOperation<Data> {
        return CallbackOperation { _, completion in
            let tempFilename = (NSTemporaryDirectory() as NSString).appendingPathComponent(self.mediaFilename ?? "file.dat")
            let outputStream = OutputStream(toFileAtPath: tempFilename, append: false)

            if let outputStream = outputStream {
                self.getMediaWith(outputStream,
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
