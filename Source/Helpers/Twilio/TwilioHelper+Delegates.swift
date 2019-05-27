//
//  TwilioHelper+Delegates.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit
import CoreData
import TwilioChatClient

extension TwilioHelper: TwilioChatClientDelegate {
    enum Notifications: String {
        case ConnectionStateUpdated = "TwilioHelper.Notifications.ConnectionStateUpdated"
        case MessageAdded = "TwilioHelper.Notifications.MessageAdded"
        case MessageAddedToSelectedChannel = "TwilioHelper.Notifications.MessageAddedToSelectedChannel"
        case ChannelAdded = "TwilioHelper.Notifications.ChannelAdded"
        case ChannelDeleted = "TwilioHelper.Notifications.ChannelDeleted"
    }

    enum NotificationKeys: String {
        case NewState = "TwilioHelper.NotificationKeys.NewState"
        case Message = "TwilioHelper.NotificationKeys.Message"
        case Channel = "TwilioHelper.NotificationKeys.Channel"
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
                try self.makeJoinOperation(channel: channel).startSync().getResult()

                let attributes = try self.getAttributes(of: channel)

                guard attributes.initiator != self.username else {
                    return
                }

                try ChatsManager.join(channel)

                try ChatsManager.makeUpdateChannelOperation(twilioChannel: channel).startSync().getResult()

                NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.ChannelAdded.rawValue),
                                                object: self)
            } catch {
//                Log.error("\(error)")
            }
        }
    }

    public func chatClient(_ client: TwilioChatClient, channel: TCHChannel, messageAdded message: TCHMessage) {
        guard message.author != self.username, channel.status == .joined else {
            return
        }

        self.queue.async {
            // FIXME
            do {
                guard let message = try MessageProcessor.process(message: message, from: channel) else {
                    NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.MessageAdded.rawValue),
                                                    object: self)
                    return
                }

                let notification: String

                if let currentChannel = self.currentChannel, channel.sid! == currentChannel.sid! {
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
            let token = try VirgilHelper.shared.client.getTwilioToken(identity: self.username)

            self.client.updateToken(token)
        } catch {
            Log.error("Update Twilio Token failed: \(error.localizedDescription)")
        }
    }

    public func chatClientTokenExpired(_ client: TwilioChatClient) {
        do {
            let token = try VirgilHelper.shared.client.getTwilioToken(identity: self.username)

            self.client.updateToken(token)
        } catch {
            Log.error("Update Twilio Token failed: \(error.localizedDescription)")
        }
    }
}
