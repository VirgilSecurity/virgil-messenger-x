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
    static let sharedInstance = TwilioHelper()
    
    private override init() {
        super.init()
    }
    
    private(set) var client: TwilioChatClient!
    private(set) var channels: TCHChannels!
    
    func initialize() {
        let token = TwilioCredentials.token
        Log.debug("Initializing Twilio")
        
        TwilioChatClient.chatClient(withToken: token, properties: nil, delegate: self) { (result, client) in
            guard let client = client, result.isSuccessful() else {
                Log.error("Error while initializing Twilio: \(result.error?.localizedDescription ?? "")")
                return
            }
            
            guard let channels = client.channelsList() else {
                Log.error("Error while initializing Twilio channels")
                return
            }
            
            Log.debug("Successfully initialized Twilio")
            self.client = client
            self.channels = channels
        }
    }
}
