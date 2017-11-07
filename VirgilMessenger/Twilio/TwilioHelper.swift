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
    var selectedChannel:Int!
    
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
                    } else {
                        Log.error("Channel NOT joined.")
                    }
                })
                
                completion(nil)
        }
    }
    
    func getLastMessages(count: Int, completion: @escaping ([DemoTextMessageModel?])->()) {
        self.channels.subscribedChannels()[self.selectedChannel].messages?.getLastWithCount(UInt(count), completion: { (result, messages) in
            var ret = [DemoTextMessageModel]()
            for message in messages! {
                let isIncoming = message.author == self.username ? false : true
                ret.append(createTextMessageModel("\(ret.count)", text: message.body!, isIncoming: isIncoming, status: .success))
            }
            completion(ret)
        })
    }
 
    func getMessages(before: Int, withCount: Int, completion: @escaping ([DemoTextMessageModel?])->()) {
        self.channels.subscribedChannels()[self.selectedChannel].messages?.getBefore(UInt(before), withCount: UInt(withCount), completion: { (result, messages) in
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
}
