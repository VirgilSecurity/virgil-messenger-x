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
    static func authorize(username: String, device: String) {
        self.sharedInstance = TwilioHelper(username: username, device: device)
    }
    
    private(set) static var sharedInstance: TwilioHelper!
    
    private init(username: String, device: String) {
        self.username = username
        self.device = device
        
        super.init()
    }
    
    private let queue = DispatchQueue(label: "TwilioHelper")
    let username: String
    private let device: String
    private let connection = ServiceConnection()
    private(set) var client: TwilioChatClient!
    private(set) var channels: TCHChannels!
    private(set) var users: TCHUsers!
    var selectedChannel: TCHChannel!
    
    func initialize(token: String, completion: @escaping (Error?)->()) {
        Log.debug("Initializing Twilio")

        self.queue.async {
            TwilioChatClient.chatClient(withToken: token, properties: nil, delegate: self) { (result, client) in
                guard let client = client, result.isSuccessful() else {
                    Log.error("Error while initializing Twilio: \(result.error?.localizedDescription ?? "")")
                    completion(NSError())
                    return
                }
                
                guard let channels = client.channelsList() else {
                    Log.error("Error while initializing Twilio channels")
                    completion(NSError())
                    return
                }

                guard let users = client.users() else {
                    Log.error("Error while initializing Twilio users")
                    completion(NSError())
                    return
                }
                
                Log.debug("Successfully initialized Twilio")
                self.client = client
                self.channels = channels
                self.users = users
                
                completion(nil)
                
                for channel in channels.subscribedChannels() {
                    if channel.status == TCHChannelStatus.invited {
                        channel.join() { channelResult in
                            if channelResult.isSuccessful() {
                                Log.debug("Successfully accepted invite.");
                                let identity = self.getCompanion(ofChannel: channel)
                                Log.debug("identity: \(identity)")
                                VirgilHelper.sharedInstance.getCard(withIdentity: identity) { card, error in
                                    guard let card = card, error == nil else {
                                        Log.error("failed to add new channel card")
                                        return
                                    }
                                    VirgilHelper.sharedInstance.channelsCards.append(card)
                                    Log.debug("new card added")
                                }
                                
                                CoreDataHelper.sharedInstance.createChannel(withName: identity)
                                
                                NotificationCenter.default.post(
                                    name: Notification.Name(rawValue: TwilioHelper.Notifications.ChannelAdded.rawValue),
                                    object: self,
                                    userInfo: [:])
                            } else {
                                Log.error("Failed to accept invite.");
                            }
                        }
                    }
                }
            }
        }
    }
    
    func setChannel(withUsername username: String) {
        for channel in channels.subscribedChannels() {
            if getCompanion(ofChannel: channel) == username {
                self.selectedChannel = channel
                return
            }
        }
    }
    
    func createChannel(withUsername username: String, completion: @escaping (Error?)->()) {
        TwilioHelper.sharedInstance.channels.createChannel(options: [
            TCHChannelOptionType: TCHChannelType.private.rawValue,
            TCHChannelOptionAttributes: [
                "initiator": self.username,
                "responder": username
            ]
        ]) { (result, channel) in
            guard let channel = channel, result.isSuccessful() else {
                Log.error("Error while creating chat with \(username): \(result.error?.localizedDescription ?? "")")
                completion(result.error ?? NSError())
                return
            }
            
            channel.members?.invite(byIdentity: username) { (result) in
                guard result.isSuccessful() else {
                    Log.error("Error while inviting member \(username): \(result.error?.localizedDescription ?? "")")
                    completion(result.error ?? NSError())
                    channel.destroy { result in
                        guard result.isSuccessful() else {
                            Log.error("can't destroy channel")
                            return
                        }
                        CoreDataHelper.sharedInstance.deleteChannel(withName: username)
                    }
                    return
                }
            }
                
                VirgilHelper.sharedInstance.getCard(withIdentity: username) { card, error in
                    guard let card = card, error == nil else {
                        Log.error("failed to add new channel card")
                        channel.destroy { result in
                            guard result.isSuccessful() else {
                                Log.error("can't destroy channel")
                                return
                            }
                        }
                        return
                    }
                    VirgilHelper.sharedInstance.channelsCards.append(card)
                }
                
                channel.join(completion: { channelResult in
                    if channelResult.isSuccessful() {
                        Log.debug("Channel joined.")
                        completion(nil)
                    } else {
                        Log.error("Channel NOT joined.")
                        completion(NSError())
                    }
                })
        }
    }
    
    func getLastMessages(count: Int, completion: @escaping ([DemoTextMessageModel?])->()) {
        self.selectedChannel.messages?.getLastWithCount(UInt(count), completion: { (result, messages) in
            var ret = [DemoTextMessageModel]()
            for message in messages! {
                let isIncoming = message.author == self.username ? false : true
                ret.append(createTextMessageModel("\(ret.count)", text: message.body!, isIncoming: isIncoming, status: .success))
            }
            completion(ret)
        })
    }
 
    func getMessages(before: Int, withCount: Int, completion: @escaping ([DemoTextMessageModel?])->()) {
        self.selectedChannel.messages?.getBefore(UInt(before), withCount: UInt(withCount), completion: { (result, messages) in
            var ret = [DemoTextMessageModel]()
            for message in messages! {
                let isIncoming = message.author == self.username ? false : true
                ret.append(createTextMessageModel("\(ret.count)", text: message.body!, isIncoming: isIncoming, status: .success))
            }
            completion(ret)
        })
    }
    
    func getCompanion(ofChannel: Int) -> String {
        let channel = TwilioHelper.sharedInstance.channels.subscribedChannels()[ofChannel]
        guard let attributes = channel.attributes(),
            let initiator = attributes["initiator"] as? String,
            let responder = attributes["responder"] as? String
            else {
                Log.error("Error: Didn't find channel attributes")
                return "Error name"
        }
        
        let result =  initiator == self.username ? responder : initiator
        return result
    }
    
    func getCompanion(ofChannel channel: TCHChannel) -> String {
        guard let attributes = channel.attributes(),
            let initiator = attributes["initiator"] as? String,
            let responder = attributes["responder"] as? String
            else {
                Log.error("Error: Didn't find channel attributes")
                return "Error name"
        }
        
        let result =  initiator == self.username ? responder : initiator
        return result
    }
}
