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
        case ejabberdHost
        case pushHost
        case backendHost
    }

    public func set(identity: String, ejabberdHost: String, pushHost: String, backendHost: String) {
        self.defaults.set(identity, forKey: Key.identity.rawValue)
        self.defaults.set(ejabberdHost, forKey: Key.ejabberdHost.rawValue)
        self.defaults.set(pushHost, forKey: Key.pushHost.rawValue)
        self.defaults.set(backendHost, forKey: Key.backendHost.rawValue)
    }

    public func set(unreadCount: Int) {
        self.defaults.set(unreadCount, forKey: Key.unreadCount.rawValue)
    }

    public func get<T>(_ key: Key) -> T? {
        let result: Any?

        switch key {
        case .identity, .ejabberdHost, .pushHost, .backendHost:
            guard let string = self.defaults.string(forKey: key.rawValue), !string.isEmpty else {
                return nil
            }

            result = string
        case .unreadCount:
            result = self.defaults.integer(forKey: key.rawValue)
        }

        return result as? T
    }

    public func reset(_ key: Key) {
        self.defaults.set(nil, forKey: key.rawValue)
    }

    public func reset() {
        Key.allCases.forEach {
            self.reset($0)
        }
    }
}
