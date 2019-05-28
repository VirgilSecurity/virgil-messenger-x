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
}

public class TwilioHelper: NSObject {
    private(set) static var shared: TwilioHelper!
    private(set) var client: TwilioChatClient!
    private(set) var channels: TCHChannels!
    private(set) var users: TCHUsers!
    private(set) var currentChannel: TCHChannel?

    let username: String
    let queue = DispatchQueue(label: "TwilioHelper")
    private let device: String

    public enum MessageType: String, Codable {
        case regular
        case service
    }

    enum MediaType: String {
        case photo = "image/bmp"
        case audio = "audio/mp4"
    }

    static func authorize(username: String, device: String) {
        self.shared = TwilioHelper(username: username, device: device)
    }

    private init(username: String, device: String) {
        self.username = username
        self.device = device

        super.init()
    }

    public static func makeInitTwilioOperation(identity: String, client: Client) -> GenericOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let token = try client.getTwilioToken(identity: identity)

                TwilioHelper.authorize(username: identity, device: "iPhone")
                TwilioHelper.shared.initialize(token: token) { error in
                    if let error = error {
                        completion(nil, error)
                    } else {
                        completion((), error)
                    }
                }
            } catch {
                completion(nil, error)
            }
        }
    }

    func initialize(token: String, completion: @escaping (Error?) -> Void) {
        Log.debug("Initializing Twilio")

        self.queue.async {
            TwilioChatClient.chatClient(withToken: token, properties: nil, delegate: self) { result, client in
                guard let client = client, result.isSuccessful() else {
                    Log.error("Error while initializing Twilio: \(result.error?.localizedDescription ?? "")")
                    completion(TwilioHelperError.initFailed)
                    return
                }

                guard let channels = client.channelsList() else {
                    Log.error("Error while initializing Twilio channels")
                    completion(TwilioHelperError.initChannelsFailed)
                    return
                }

                guard let users = client.users() else {
                    Log.error("Error while initializing Twilio users")
                    completion(TwilioHelperError.initUsersFailed)
                    return
                }

                self.client = client
                self.channels = channels
                self.users = users

                Log.debug("Successfully initialized Twilio")

                for channel in channels.subscribedChannels() {
                    // FIXME: Huge Twilio bug!!!
                    while channel.messages == nil || channel.attributes() == nil { sleep(1) }

                    Log.debug(String(describing: channel.attributes()))
                }

                completion(nil)
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
