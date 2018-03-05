//
//  TwilioHelper.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation
import TwilioChatClient

class TwilioHelper: NSObject {
    private(set) static var sharedInstance: TwilioHelper!
    private(set) var client: TwilioChatClient!
    private(set) var channels: TCHChannels!
    private(set) var users: TCHUsers!
    private(set) var currentChannel: TCHChannel!

    let username: String
    private let queue = DispatchQueue(label: "TwilioHelper")
    private let device: String
    private let connection = ServiceConnection()

    enum TwilioHelperError: Int, Error {
        case initFailed
        case initChannelsFailed
        case initUsersFailed
        case joiningFailed
    }

    static func authorize(username: String, device: String) {
        self.sharedInstance = TwilioHelper(username: username, device: device)
    }

    private init(username: String, device: String) {
        self.username = username
        self.device = device

        super.init()
    }

    func initialize(token: String, completion: @escaping (Error?) -> ()) {
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

                Log.debug("Successfully initialized Twilio")
                self.client = client
                self.channels = channels
                self.users = users

                self.joinChannels(channels)
                completion(nil)
            }
        }
    }
    
    func getCompanion(ofChannel channel: TCHChannel) -> String {
        guard let attributes = channel.attributes(),
            let initiator = attributes["initiator"] as? String,
            let responder = attributes["responder"] as? String
            else {
                Log.error("Error: Didn't find channel attributes")
                return "Error name"
        }

        let result = initiator == self.username ? responder : initiator
        return result
    }
}

// Setters
extension TwilioHelper {
    func setChannel(withUsername username: String) {
        for channel in channels.subscribedChannels() {
            if getCompanion(ofChannel: channel) == username {
                self.currentChannel = channel
                return
            }
        }
    }

    func deselectChannel() {
        self.currentChannel = nil
    }
}
