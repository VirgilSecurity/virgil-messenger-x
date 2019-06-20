//
//  Twilio+Delegates.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import TwilioChatClient

extension Twilio {
    enum Notifications: String {
        case ConnectionStateUpdated = "Twilio.Notifications.ConnectionStateUpdated"
        case MessageAdded = "Twilio.Notifications.MessageAdded"
        case MessageAddedToSelectedChannel = "Twilio.Notifications.MessageAddedToSelectedChannel"
        case ChannelAdded = "Twilio.Notifications.ChannelAdded"
        case ChannelDeleted = "Twilio.Notifications.ChannelDeleted"
    }

    enum NotificationKeys: String {
        case NewState = "Twilio.NotificationKeys.NewState"
        case Message = "Twilio.NotificationKeys.Message"
        case Channel = "Twilio.NotificationKeys.Channel"
    }

    enum ConnectionState: String {
        case unknown = "unknown"
        case disconnected = "disconnected"
        case connected = "connected"
        case connecting = "connecting"
        case denied = "denied"
        case error = "error"

        init(state: TCHClientConnectionState) {
            switch state {
            case .unknown: self = .unknown
            case .disconnected: self = .disconnected
            case .connected: self = .connected
            case .connecting: self = .connecting
            case .denied: self = .denied
            case .error: self = .error
            @unknown default:
                self = .unknown
            }
        }
    }
}

extension Twilio: TwilioChatClientDelegate {
    public func chatClient(_ client: TwilioChatClient, connectionStateUpdated state: TCHClientConnectionState) {
        let connectionState = ConnectionState(state: state)

        let stateStr = connectionState.rawValue
        Log.debug("\(stateStr)")

        NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.ConnectionStateUpdated.rawValue),
                                        object: self,
                                        userInfo: [NotificationKeys.NewState.rawValue: connectionState])
    }

    public func chatClient(_ client: TwilioChatClient, channelAdded channel: TCHChannel) {
        self.queue.async {
            do {
                if channel.status != .joined {
                    try channel.join().startSync().getResult()

                    let attributes = try channel.getAttributes()

                    guard attributes.initiator != self.identity else {
                        return
                    }
                    
                    try ChatsManager.join(channel)

                    try ChatsManager.makeUpdateChannelOperation(twilioChannel: channel).startSync().getResult()

                    NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.ChannelAdded.rawValue),
                                                    object: self)
                }
            } catch {
                Log.error("\(error)")
            }
        }
    }

    public func chatClient(_ client: TwilioChatClient, channel: TCHChannel, messageAdded message: TCHMessage) {
        guard message.author != self.identity, channel.status == .joined else {
            return
        }

        self.queue.async {
            do {
                guard let message = try MessageProcessor.process(message: message, from: channel) else {
                    NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.MessageAdded.rawValue),
                                                    object: self)
                    return
                }

                let notification: String

                if let currentChannel = self.currentChannel, try channel.getSid() == currentChannel.getSid() {
                    notification = Notifications.MessageAddedToSelectedChannel.rawValue
                } else {
                    notification = Notifications.MessageAdded.rawValue
                }

                NotificationCenter.default.post(name: Notification.Name(rawValue: notification),
                                                object: self,
                                                userInfo: [NotificationKeys.Message.rawValue: message])
            } catch {
                Log.error("\(error)")
            }
        }
    }

    public func chatClientTokenWillExpire(_ client: TwilioChatClient) {
        do {
            let token = try Virgil.shared.client.getTwilioToken(identity: self.identity)

            self.client.updateToken(token)
        } catch {
            Log.error("Update Twilio Token failed: \(error.localizedDescription)")
        }
    }

    public func chatClientTokenExpired(_ client: TwilioChatClient) {
        do {
            let token = try Virgil.shared.client.getTwilioToken(identity: self.identity)

            self.client.updateToken(token)
        } catch {
            Log.error("Update Twilio Token failed: \(error.localizedDescription)")
        }
    }
}
