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
    static func initialize(username: String, device: String) {
        self.sharedInstance = TwilioHelper(username: username, device: device)
        self.sharedInstance.initialize()
    }
    
    private(set) static var sharedInstance: TwilioHelper!
    
    private init(username: String, device: String) {
        self.username = username
        self.device = device
        
        super.init()
    }
    
    private let queue = DispatchQueue(label: "TwilioHelper")
    private let username: String
    private let device: String
    private let connection = ServiceConnection()
    private(set) var client: TwilioChatClient!
    private(set) var channels: TCHChannels!
    private(set) var users: TCHUsers!
    
    func initialize() {
        Log.debug("Initializing Twilio")
        
        self.queue.async {
            let token: String
            do {
                let tokenRequest = try ServiceRequest(
                    url: URL(string: "https://demo-ip-messaging.virgilsecurity.com/auth/twilio-token")!,
                    method: .get,
                    params: [
                        "identity": self.username,
                        "device": self.device
                    ])
                
                let response = try self.connection.send(tokenRequest)
                
                guard let data = response.body else {
                    throw NSError(domain: "TwilioHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty data"])
                }
                
                let resp = try JSONSerialization.jsonObject(with: data, options: [])
                
                guard let dict = resp as? [String : Any],
                    let t = dict["twilio_token"] as? String else {
                        throw NSError(domain: "TwilioHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "No token"])
                }
                
                token = t
            }
            catch {
                Log.error("Error while getting token: \(error.localizedDescription)")
                return
            }
            
            TwilioChatClient.chatClient(withToken: token, properties: nil, delegate: self) { (result, client) in
                guard let client = client, result.isSuccessful() else {
                    Log.error("Error while initializing Twilio: \(result.error?.localizedDescription ?? "")")
                    return
                }
                
                guard let channels = client.channelsList() else {
                    Log.error("Error while initializing Twilio channels")
                    return
                }
                
                guard let users = client.users() else {
                    Log.error("Error while initializing Twilio users")
                    return
                }
                
                Log.debug("Successfully initialized Twilio")
                self.client = client
                self.channels = channels
                self.users = users
            }
        }
    }
}
