//
//  TwilioHelper.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit
import TwilioChatClient
import VirgilSDK

public enum TwilioHelperError: Int, Error {
    case initFailed = 1
    case initChannelsFailed = 2
    case initUsersFailed = 3
    case invalidChannel = 4
    case invalidMessage = 5
    case nilCurrentChannel = 6
}

public class TwilioHelper: NSObject {
    public static var updatedPushToken: Data?
    private(set) static var shared: TwilioHelper!
    private(set) var client: TwilioChatClient!
    private(set) var channels: TCHChannels!
    private(set) var users: TCHUsers!
    private(set) var currentChannel: TCHChannel?

    let identity: String
    let queue = DispatchQueue(label: "TwilioHelper")

    enum MediaType: String {
        case photo = "image/bmp"
        case audio = "audio/mp4"
    }

    public func getCurrentChannel() throws -> TCHChannel {
        guard let channel = self.currentChannel else {
            throw TwilioHelperError.nilCurrentChannel
        }

        return channel
    }

    public static func makeInitTwilioOperation(identity: String, client: Client) -> GenericOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let token = try client.getTwilioToken(identity: identity)

                self.shared = TwilioHelper(identity: identity)

                Log.debug("Initializing Twilio")

                try self.shared.initialize(token: token).startSync().getResult()

                if let token = self.updatedPushToken {
                    try self.shared.register(withNotificationToken: token).startSync().getResult()
                }

                for channel in self.shared.channels.subscribedChannels() {
                    // FIXME: Huge Twilio bug!!!
                    while channel.messages == nil || channel.attributes() == nil { sleep(1) }

                    Log.debug(String(describing: channel.attributes()))
                }

                Log.debug("Successfully initialized Twilio")

                completion((), nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    private init(identity: String) {
        self.identity = identity

        super.init()
    }

    private func initialize(token: String) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            TwilioChatClient.chatClient(withToken: token, properties: nil, delegate: self) { result, client in
                do {
                    if let error = result.error {
                        throw error
                    }

                    guard let client = client else {
                        throw TwilioHelperError.initFailed
                    }

                    guard let channels = client.channelsList() else {
                        throw TwilioHelperError.initChannelsFailed
                    }

                    guard let users = client.users() else {
                        throw TwilioHelperError.initUsersFailed
                    }

                    self.client = client
                    self.channels = channels
                    self.users = users

                    completion((), nil)
                } catch {
                    completion(nil, error)
                }
            }
        }
    }

    private func register(withNotificationToken token: Data) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            self.client.register(withNotificationToken: token) { result in
                if let error = result.error {
                    completion(nil, error)
                } else {
                    completion((), nil)
                }
            }
        }
    }

    public func deregister(withNotificationToken token: Data) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            self.client.deregister(withNotificationToken: token) { result in
                if let error = result.error {
                    completion(nil, error)
                } else {
                    completion((), nil)
                }
            }
        }
    }
}

// Setters
extension TwilioHelper {
    func getChannel(_ channel: Channel) -> TCHChannel? {
        return self.channels.subscribedChannels().first { $0.sid! == channel.sid }
    }

    func setChannel(_ channel: Channel) {
        self.currentChannel = self.getChannel(channel)
    }

    func deselectChannel() {
        self.currentChannel = nil
    }
}
