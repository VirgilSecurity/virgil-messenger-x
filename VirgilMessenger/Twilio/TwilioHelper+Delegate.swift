//
//  TwilioHelper+Delegate.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation
import TwilioChatClient

extension TwilioHelper: TwilioChatClientDelegate {
    enum Notifications: String {
        case ConnectionStateUpdated = "TwilioHelper.Notifications.ConnectionStateUpdated"
        case MessageAdded           = "TwilioHelper.Notifications.MessageAdded"
        case ChannelAdded           = "TwilioHelper.Notifications.ChannelAdded"
    }
    
    enum NotificationKeys: String {
        case NewState = "TwilioHelper.NotificationKeys.NewState"
        case Message  = "TwilioHelper.NotificationKeys.Message"
        case Channel  = "TwilioHelper.NotificationKeys.Channel"
    }
    
    enum ConnectionState: String {
        case unknown       = "unknown"
        case disconnected  = "disconnected"
        case connected     = "connected"
        case connecting    = "connecting"
        case denied        = "denied"
        case error         = "error"
        
        init(state: TCHClientConnectionState) {
            switch state {
            case .unknown:       self = .unknown
            case .disconnected:  self = .disconnected
            case .connected:     self = .connected
            case .connecting:    self = .connecting
            case .denied:        self = .denied
            case .error:         self = .error
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
    
    func chatClient(_ client: TwilioChatClient, channel: TCHChannel, messageAdded message: TCHMessage) {
        
        if (channel == self.channels.subscribedChannels()[self.selectedChannel] && message.author != self.username) {
            NotificationCenter.default.post(
                name: Notification.Name(rawValue: TwilioHelper.Notifications.MessageAdded.rawValue),
                object: self,
                userInfo: [
                    TwilioHelper.NotificationKeys.Message.rawValue: message
                ])
        }
    }
    
    func chatClient(_ client: TwilioChatClient, channelAdded channel: TCHChannel) {
        Log.debug("Channel added")
        if(channel.status == TCHChannelStatus.invited) {
            channel.join() { channelResult in
                if channelResult.isSuccessful() {
                    print("Successfully accepted invite.");
                    NotificationCenter.default.post(
                        name: Notification.Name(rawValue: TwilioHelper.Notifications.ChannelAdded.rawValue),
                        object: self,
                        userInfo: [:])
                } else {
                    print("Failed to accept invite.");
                }
            }
        }
    }
}
