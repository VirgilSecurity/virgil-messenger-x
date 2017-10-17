//
//  TwilioHelper.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation
import TwilioChatClient

class TwilioHelper: NSObject, TwilioChatClientDelegate {
    static let sharedInstance = TwilioHelper()
    
    private override init() {
        super.init()
    }
    
    private var client: TwilioChatClient!
    
    func initialize() {
        let token = TwilioCredentials.token
        Log.debug("Initializing Twilio")
        
        TwilioChatClient.chatClient(withToken: token, properties: nil, delegate: self) { (result, client) in
            guard let client = client, result.isSuccessful() else {
                Log.error("Error while initializing Twilio: \(result.error?.localizedDescription ?? "")")
                return
            }
            
            Log.debug("Successfully initialized Twilio")
            self.client = client
        }
    }
}
