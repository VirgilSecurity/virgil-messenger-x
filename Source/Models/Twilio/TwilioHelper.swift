//
//  TwilioHelper.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation
import TwilioChatClient
import TwilioAccessManager
import VirgilSDK

class TwilioHelper: NSObject {
    private(set) static var shared: TwilioHelper!
    private(set) var client: TwilioChatClient!
    private(set) var channels: TCHChannels!
    private(set) var users: TCHUsers!
    private(set) var currentChannel: TCHChannel?
    private(set) var accessManager: TwilioAccessManager!

    let username: String
    let queue = DispatchQueue(label: "TwilioHelper")
    private let device: String

    enum TwilioHelperError: Error {
        case initFailed
        case initChannelsFailed
        case initUsersFailed
        case joiningFailed
        case missingChannelAttributes
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

            self.accessManager = TwilioAccessManager(token: token, delegate: self)

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

                self.accessManager?.registerClient(client, forUpdates: { [weak client = self.client] (token) in
                    client?.updateToken(token) { (result) in
                        guard result.error == nil else {
                            Log.error("Update Twilio Token failed: \(result.error?.localizedDescription ?? "unknown error")")
                            return
                        }
                    }
                })

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
    
    func getCompanion(of channel: TCHChannel) -> String {
        guard let attributes = try? self.getAttributes(of: channel) else {
            Log.error("Missing channel attributes")
            return "Error name"
        }

        return attributes.members.first { $0 != self.username } ?? "Error name"
    }
}

// Setters
extension TwilioHelper {
    func setChannel(_ coreDataChannel: Channel) {
        for channel in channels.subscribedChannels() {
            if self.getName(of: channel) == coreDataChannel.name {
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
