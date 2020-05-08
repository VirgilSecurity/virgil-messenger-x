//
//  IdentityDefaults.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 13.02.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

public class SharedDefaults {
    public static let shared: SharedDefaults = SharedDefaults()

    private let defaults: UserDefaults = UserDefaults(suiteName: Constants.appGroup)!

    public enum Key: String, CaseIterable {
        case identity = "last_username"
        case unreadCount = "unread_count"
    }

    public func set(identity: String) {
        self.defaults.set(identity, forKey: Key.identity.rawValue)
    }

    public func set(unreadCount: Int) {
        self.defaults.set(unreadCount, forKey: Key.unreadCount.rawValue)
    }

    public func get<T>(_ key: Key) -> T? {
        let result: Any?

        switch key {
        case .identity:
            guard let identity = self.defaults.string(forKey: key.rawValue), !identity.isEmpty else {
                return nil
            }

            result = identity
        case .unreadCount:
            result = self.defaults.integer(forKey: key.rawValue)
        }

        return result as? T
    }

    public func reset(_ key: Key) {
        self.defaults.set(nil, forKey: key.rawValue)
    }
}
