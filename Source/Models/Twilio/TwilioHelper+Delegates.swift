//
//  TwilioHelper+Delegates.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit
import CoreData
import Foundation
import TwilioChatClient
import TwilioAccessManager

extension TwilioHelper: TwilioChatClientDelegate {
    enum Notifications: String {
        case ConnectionStateUpdated = "TwilioHelper.Notifications.ConnectionStateUpdated"
        case MessageAdded = "TwilioHelper.Notifications.MessageAdded"
        case MessageAddedToSelectedChannel = "TwilioHelper.Notifications.MessageAddedToSelectedChannel"
        case ChannelAdded = "TwilioHelper.Notifications.ChannelAdded"
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

    func chatClient(_ client: TwilioChatClient, connectionStateUpdated state: TCHClientConnectionState) {
        let connectionState = ConnectionState(state: state)

        let stateStr = connectionState.rawValue
        Log.debug("\(stateStr)")

        NotificationCenter.default.post(
            name: Notification.Name(rawValue: TwilioHelper.Notifications.ConnectionStateUpdated.rawValue),
            object: self,
            userInfo: [
                TwilioHelper.NotificationKeys.NewState.rawValue: connectionState
            ])
    }

    func chatClient(_ client: TwilioChatClient, channelAdded channel: TCHChannel) {
        self.queue.async {
            do {
                try self.makeJoinOperation(channel: channel).startSync().getResult()

                let attributes = try self.getAttributes(of: channel)

                let identity = attributes.initiator

                guard identity != self.username else {
                    return
                }

                let card = try VirgilHelper.shared.makeGetCardOperation(identity: identity).startSync().getResult()
                try CoreDataHelper.shared.createChannel(type: .single, name: identity, cards: [card])

                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: TwilioHelper.Notifications.ChannelAdded.rawValue),
                    object: self,
                    userInfo: [:])
            } catch {
                Log.error("\(error)")
            }
        }
    }

    func chatClient(_ client: TwilioChatClient, channel: TCHChannel, messageAdded message: TCHMessage) {
        guard message.author != self.username else {
            return
        }

        self.queue.async {
            // FIXME
            do {
                let message = try MessageProcessor.process(message: message, from: channel)

                let notification: String

                if let currentChannel = self.currentChannel,
                    self.getName(of: channel) == self.getName(of: currentChannel) {
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
}

extension TwilioHelper: TwilioAccessManagerDelegate {
    func accessManagerTokenWillExpire(_ accessManager: TwilioAccessManager) {
        do {
            let token = try VirgilHelper.shared.client.getTwilioToken(identity: self.username)

            accessManager.updateToken(token)
        } catch {
            Log.error("Update Twilio Token failed: \(error.localizedDescription)")
        }

    }
}
