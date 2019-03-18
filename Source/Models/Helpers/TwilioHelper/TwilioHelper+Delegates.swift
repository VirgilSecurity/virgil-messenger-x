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
        Log.debug("Channel added")
        self.join(channel: channel)
    }

    func chatClient(_ client: TwilioChatClient, channelDeleted channel: TCHChannel) {
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: TwilioHelper.Notifications.ChannelAdded.rawValue),
            object: self,
            userInfo: [:])
    }

    func chatClient(_ client: TwilioChatClient, channel: TCHChannel, messageAdded message: TCHMessage) {
        Log.debug("Message added")
        if let currentChannel = self.currentChannel,
            self.getName(of: channel) == self.getName(of: currentChannel) {
                Log.debug("it's from selected channel")
                if message.author != self.username {
                    Log.debug("author is not me")
                    NotificationCenter.default.post(
                        name: Notification.Name(rawValue: TwilioHelper.Notifications.MessageAddedToSelectedChannel.rawValue),
                        object: self,
                        userInfo: [
                            TwilioHelper.NotificationKeys.Message.rawValue: message
                        ])
                }
        } else {
            self.processMessage(channel: channel, message: message)
        }
    }

    func chatClient(_ client: TwilioChatClient, channel: TCHChannel, memberJoined member: TCHMember) {
        if self.getType(of: channel) == ChannelType.group,
            let name = self.getName(of: channel),
            let coreChannel = CoreDataHelper.shared.getChannel(withName: name) {
                Log.debug("New member joined")
                guard let identity = member.identity else {
                    Log.error("Member identity is unaccessable")
                    return
                }
                VirgilHelper.shared.getExportedCard(identity: identity) { exportedCard, error in
                    guard error == nil, let exportedCard = exportedCard else {
                        return
                    }
                    CoreDataHelper.shared.addMember(card: exportedCard, to: coreChannel)

                    // FIXME
                    guard let card = CoreDataHelper.shared.currentChannel?.cards.first else {
                        Log.error("Fetching current channel cards failed")
                        return
                    }
                    
                    VirgilHelper.shared.setChannelCard(card)
                }
        }
    }

    private func processMessage(channel: TCHChannel, message: TCHMessage) {
        guard let messageDate = message.dateUpdatedAsDate else {
            Log.error("Got corrupted message")
            return
        }
        guard let channelName = self.getName(of: channel) else {
            return
        }
        guard let coreDataChannel = CoreDataHelper.shared.getChannel(withName: channelName) else {
            Log.error("Can't get core data channel")
            return
        }

        if message.hasMedia() {
            self.getMedia(from: message) { encryptedData in
                guard let encryptedData = encryptedData,
                    let encryptedString = String(data: encryptedData, encoding: .utf8),
                    let decryptedString = VirgilHelper.shared.decrypt(encryptedString),
                    let decryptedData = Data(base64Encoded: decryptedString) else {
                        Log.error("Decryption process of media message failed")
                        return
                }
                coreDataChannel.lastMessagesDate = messageDate

                if (coreDataChannel.message?.count == 0 || (Int(truncating: message.index ?? 0) >= (coreDataChannel.message?.count ?? 0))) {
                    switch message.mediaType {
                    case MediaType.photo.rawValue:
                        coreDataChannel.lastMessagesBody = CoreDataHelper.shared.lastMessageIdentifier[CoreDataHelper.MessageType.photo.rawValue]
                            ?? "corrupted type"
                        CoreDataHelper.shared.createMediaMessage(for: coreDataChannel, with: decryptedData,
                                                                         isIncoming: true, date: messageDate, type: .photo)
                    case MediaType.audio.rawValue:
                        coreDataChannel.lastMessagesBody = CoreDataHelper.shared.lastMessageIdentifier[CoreDataHelper.MessageType.audio.rawValue]
                            ?? "corrupted type"
                        CoreDataHelper.shared.createMediaMessage(for: coreDataChannel, with: decryptedData,
                                                                         isIncoming: true, date: messageDate, type: .audio)
                    default:
                        Log.error("Missing or unknown mediaType")
                        return
                    }
                }
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: TwilioHelper.Notifications.MessageAdded.rawValue),
                    object: self,
                    userInfo: [
                        TwilioHelper.NotificationKeys.Message.rawValue: message
                    ])
            }
        } else if let messageBody = message.body {
            guard let decryptedMessageBody = VirgilHelper.shared.decrypt(messageBody) else {
                return
            }

            coreDataChannel.lastMessagesBody = decryptedMessageBody
            coreDataChannel.lastMessagesDate = messageDate

            if (coreDataChannel.message?.count == 0 || (Int(truncating: message.index ?? 0) >= (coreDataChannel.message?.count ?? 0))) {
                CoreDataHelper.shared.createTextMessage(for: coreDataChannel, withBody: decryptedMessageBody,
                                                                isIncoming: true, date: messageDate)
            }
            Log.debug("Receiving " + decryptedMessageBody)
            NotificationCenter.default.post(
                name: Notification.Name(rawValue: TwilioHelper.Notifications.MessageAdded.rawValue),
                object: self,
                userInfo: [
                    TwilioHelper.NotificationKeys.Message.rawValue: message
                ])
        }
    }
}

extension TwilioHelper: TwilioAccessManagerDelegate {
    func accessManagerTokenWillExpire(_ accessManager: TwilioAccessManager) {
        do {
            let token = try VirgilHelper.shared.getTwilioToken(identity: self.username)

            accessManager.updateToken(token)
        } catch {
            Log.error("Update Twilio Token failed: \(error.localizedDescription)")
        }

    }
}
