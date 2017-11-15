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
                
                self.joinChannels(channels)
            }
        }
    }
    
    private func joinChannels(_ channels: TCHChannels) {
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
                            CoreDataHelper.sharedInstance.createChannel(withName: identity, card: card.exportData())
                            Log.debug("new card added")
                        }
                        
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
    
    func setChannel(withUsername username: String) {
        for channel in channels.subscribedChannels() {
            if getCompanion(ofChannel: channel) == username {
                self.selectedChannel = channel
                return
            }
        }
    }
    
    func createChannel(withUsername username: String, completion: @escaping (Error?)->()) {
        VirgilHelper.sharedInstance.getCard(withIdentity: username) { card, error in
            guard let card = card, error == nil else {
                Log.error("failed to add new channel card")
                DispatchQueue.main.async {
                    completion(error)
                }
                return
            }
            CoreDataHelper.sharedInstance.createChannel(withName: username, card: card.exportData())
            
            TwilioHelper.sharedInstance.channels.createChannel(options: [
                TCHChannelOptionType: TCHChannelType.private.rawValue,
                TCHChannelOptionAttributes: [
                    "initiator": self.username,
                    "responder": username
                ]
            ]) { (result, channel) in
                guard let channel = channel, result.isSuccessful() else {
                    Log.error("Error while creating chat with \(username): \(result.error?.localizedDescription ?? "")")
                    DispatchQueue.main.async {
                        completion(result.error ?? NSError())
                    }
                    CoreDataHelper.sharedInstance.deleteChannel(withName: username)
                    return
                }
                
                channel.members?.invite(byIdentity: username) { (result) in
                    guard result.isSuccessful() else {
                        Log.error("Error while inviting member \(username): \(result.error?.localizedDescription ?? "")")
                        DispatchQueue.main.async {
                            completion(result.error ?? NSError())
                        }
                        channel.destroy { result in
                            guard result.isSuccessful() else {
                                Log.error("can't destroy channel")
                                CoreDataHelper.sharedInstance.deleteChannel(withName: username)
                                return
                            }
                            CoreDataHelper.sharedInstance.deleteChannel(withName: username)
                        }
                        return
                    }
                }
                
                channel.join(completion: { channelResult in
                    if channelResult.isSuccessful() {
                        Log.debug("Channel joined.")
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                    } else {
                        Log.error("Channel NOT joined.")
                        DispatchQueue.main.async {
                            completion(NSError())
                        }
                    }
                })
            }
        }
    }
    
    func getLastMessages(count: Int, completion: @escaping ([DemoTextMessageModel?])->()) {
        self.selectedChannel.messages?.getLastWithCount(UInt(count), completion: { (result, messages) in
            var ret = [DemoTextMessageModel]()
            for message in messages! {
                let isIncoming = message.author == self.username ? false : true
                ret.append(createTextMessageModel("\(ret.count)", text: message.body!, isIncoming: isIncoming, status: .success, date: message.dateUpdatedAsDate!))
            }
            completion(ret)
        })
    }
 
    func getMessages(before: Int, withCount: Int, completion: @escaping ([DemoTextMessageModel?])->()) {
        self.selectedChannel.messages?.getBefore(UInt(before), withCount: UInt(withCount), completion: { (result, messages) in
            var ret = [DemoTextMessageModel]()
            for message in messages! {
                let isIncoming = message.author == self.username ? false : true
                ret.append(createTextMessageModel("\(ret.count)", text: message.body!, isIncoming: isIncoming, status: .success, date: message.dateUpdatedAsDate!))
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
