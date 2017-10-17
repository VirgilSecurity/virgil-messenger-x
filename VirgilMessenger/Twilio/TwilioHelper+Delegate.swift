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
    func chatClient(_ client: TwilioChatClient, connectionStateUpdated state: TCHClientConnectionState) {
        let stateStr = { () -> String in
            switch state {
            case .unknown:       return "unknown"
            case .disconnected:  return "disconnected"
            case .connected:     return "connected"
            case .connecting:    return "connecting"
            case .denied:        return "denied"
            case .error:         return "error"
            }
        }()
        
        Log.debug("\(stateStr)")
    }
}
