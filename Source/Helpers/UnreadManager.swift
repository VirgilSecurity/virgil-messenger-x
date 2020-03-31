//
//  UnreadManager.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/26/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import UIKit

// TODO: Think of how to avoid another shared manager
public class UnreadManager {
    public static let shared = UnreadManager()
    
    public func reset() {
        SharedDefaults.shared.reset(.unreadCount)
        
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
    
    public func update() {
        let totalUnreadCount = Storage.shared.currentAccount?.totalUnreadCount() ?? 0
        
        SharedDefaults.shared.set(unreadCount: totalUnreadCount)
        
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = totalUnreadCount
        }
    }
}
