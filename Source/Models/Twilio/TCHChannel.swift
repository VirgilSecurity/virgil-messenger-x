//
//  TCHChannel.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 6/19/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import TwilioChatClient
import VirgilSDK

extension TCHChannel {
    struct Attributes: Codable {
        let type: ChannelType

        var initiator: String
        var members: [String]

        static func `import`(_ json: [String: Any]) throws -> Attributes {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])

            return try JSONDecoder().decode(Attributes.self, from: data)
        }

        func export() throws -> [String: Any] {
            let data = try JSONEncoder().encode(self)

            guard let result = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw Twilio.Error.invalidChannel
            }

            return result
        }
    }
}

extension TCHChannel {
    class Options {
        let uniqueName: String
        let friendlyName: String?
        let scope: Int
        let attributes: Attributes

        public init(uniqueName: String,
                    friendlyName: String?,
                    initiator: String,
                    members: [String],
                    scope: Int = TCHChannelType.private.rawValue,
                    type: ChannelType) {
            self.uniqueName = uniqueName
            self.friendlyName = friendlyName
            self.scope = scope
            self.attributes = Attributes(type: type, initiator: initiator, members: members)
        }

        func export() throws -> [String: Any] {
            return [TCHChannelOptionUniqueName: self.uniqueName,
                    TCHChannelOptionFriendlyName: self.friendlyName as Any,
                    TCHChannelOptionAttributes: try self.attributes.export(),
                    TCHChannelOptionType: self.scope]
        }
    }
}

extension TCHChannel {
    func getSid() throws -> String {
        guard let sid = self.sid else {
            throw Twilio.Error.invalidChannel
        }

        return sid
    }

    func getSessionId() throws -> Data {
        guard
            let name = self.uniqueName,
            let sessionId = Data(hexEncodedString: name)
        else {
            throw Twilio.Error.invalidChannel
        }

        return sessionId
    }

    func getFriendlyName() throws -> String {
        guard let name = self.friendlyName else {
            throw Twilio.Error.invalidChannel
        }

        return name
    }

    func getAttributes() throws -> Attributes {
        guard let attributes = self.attributes() else {
            throw Twilio.Error.invalidChannel
        }

        return try Attributes.import(attributes)
    }

    func setAttributes(_ attributes: Attributes) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let newAttributes = try attributes.export()

                self.setAttributes(newAttributes) { result in
                    if let error = result.error {
                        completion(nil, error)
                    } else {
                        completion((), nil)
                    }
                }
            } catch {
                completion(nil, error)
            }
        }
    }

    func join() -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            guard self.status != .joined else {
                completion((), nil)
                return
            }

            self.join { result in
                if let error = result.error {
                    completion(nil, error)
                } else {
                    completion((), nil)
                }
            }
        }
    }

    func invite(identity: String) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            guard let members = self.members else {
                completion(nil, Twilio.Error.invalidChannel)
                return
            }

            members.invite(byIdentity: identity) { result in
                if let error = result.error {
                    completion(nil, error)
                } else {
                    completion((), nil)
                }
            }
        }
    }

    func getMessagesCount() -> CallbackOperation<Int> {
        return CallbackOperation { _, completion in
            self.getMessagesCount { result, count in
                if let error = result.error {
                    completion(nil, error)
                } else {
                    completion(Int(count), nil)
                }
            }
        }
    }

    func getLastMessages(withCount count: Int) -> CallbackOperation<[TCHMessage]> {
        return CallbackOperation { _, completion in
            guard let messages = self.messages else {
                completion([], nil)
                return
            }

            messages.getLastWithCount(UInt(count)) { result, messages in
                if let error = result.error {
                    completion(nil, error)
                } else {
                    completion(messages ?? [], nil)
                }
            }
        }
    }

    func send(ciphertext: String, type: TCHMessage.Kind, identifier: String? = nil) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let options = TCHMessageOptions()
                options.withBody(ciphertext)

                let attributes = TCHMessage.Attributes(type: type, identifier: identifier)

                try options.withAttributes(attributes.export())

                guard let messages = self.messages else {
                    throw Twilio.Error.invalidChannel
                }

                messages.sendMessage(with: options) { result, _ in
                    if let error = result.error {
                        completion(nil, error)
                    } else {
                        completion((), nil)
                    }
                }
            } catch {
                completion(nil, error)
            }
        }
    }

    public func delete(message: TCHMessage) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            guard let messages = self.messages else {
                return completion(nil, Twilio.Error.invalidChannel)
            }

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
}
