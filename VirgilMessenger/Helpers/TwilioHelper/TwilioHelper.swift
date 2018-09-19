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
    let queue = DispatchQueue(label: "TwilioHelper")
    private let device: String
    private let connection = ServiceConnection()

    enum TwilioHelperError: Int, Error {
        case initFailed
        case initChannelsFailed
        case initUsersFailed
        case joiningFailed
    }

    enum MediaType: String {
        case photo = "image/bmp"
        case audio = "audio/mp4"
    }

    enum Keys: String {
        case initiator
        case responder
        case type
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

                for channel in channels.subscribedChannels() {
                    self.join(channel: channel)
                }

                completion(nil)
            }
        }
    }
    
    func getCompanion(of channel: TCHChannel) -> String {
        guard let attributes = channel.attributes(),
            let initiator = attributes[Keys.initiator.rawValue] as? String,
            let responder = attributes[Keys.responder.rawValue] as? String
            else {
                Log.error("Missing channel attributes")
                return "Error name"
        }

        let result = initiator == self.username ? responder : initiator
        return result
    }

    func getType(of channel: TCHChannel) -> ChannelType? {
        guard let attributes = channel.attributes(),
            let type = attributes[Keys.type.rawValue] as? String else {
                Log.error("Missing channel attributes")
                return nil
        }

        switch type {
        case ChannelType.single.rawValue:
            return .single
        case ChannelType.group.rawValue:
            return .group
        default:
            Log.error("Unknown twilio channel type")
            return nil
        }
    }
}

// Setters
extension TwilioHelper {
    func setChannel(withName name: String) {
        for channel in channels.subscribedChannels() {
            if self.getName(of: channel) == name {
                self.currentChannel = channel
                return
            }
        }
        Log.error("Channel not found")
    }

    func deselectChannel() {
        self.currentChannel = nil
    }
}
