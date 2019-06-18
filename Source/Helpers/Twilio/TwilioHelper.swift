//
//  TwilioHelper.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

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
    private(set) static var shared: TwilioHelper!
    private(set) var client: TwilioChatClient!
    private(set) var channels: TCHChannels!
    private(set) var users: TCHUsers!
    private(set) var currentChannel: TCHChannel?

    let identity: String
    let queue = DispatchQueue(label: "TwilioHelper")

    public enum MessageType: String, Codable {
        case regular
        case service
    }

    enum MediaType: String {
        case photo = "image/bmp"
        case audio = "audio/mp4"
    }

    public static func makeInitTwilioOperation(identity: String, client: Client) -> GenericOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let token = try client.getTwilioToken(identity: identity)

                self.shared = TwilioHelper(identity: identity)
                TwilioHelper.shared.initialize(token: token).start(completion: completion)
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
            Log.debug("Initializing Twilio")

            self.queue.async {
                TwilioChatClient.chatClient(withToken: token, properties: nil, delegate: self) { result, client in
                    do {
                        guard let client = client, result.isSuccessful() else {
                            throw result.error ?? TwilioHelperError.initFailed
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

                        for channel in channels.subscribedChannels() {
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
