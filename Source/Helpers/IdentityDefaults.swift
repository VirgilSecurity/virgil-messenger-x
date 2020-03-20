//
//  IdentityDefaults.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 13.02.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

public class IdentityDefaults {
    public static let shared: IdentityDefaults = IdentityDefaults()

    private let defaults: UserDefaults = UserDefaults(suiteName: Constants.appGroup)!

    private static let IdentityKey = "last_username"

    public func set(identity: String) {
        self.defaults.set(identity, forKey: IdentityDefaults.IdentityKey)
    }

    public func get() -> String? {
        guard let identity = self.defaults.string(forKey: IdentityDefaults.IdentityKey), !identity.isEmpty else {
            return self.deprecatedGet()
        }

        return identity
    }

    private func deprecatedGet() -> String? {
        guard let identity = UserDefaults.standard.string(forKey: IdentityDefaults.IdentityKey), !identity.isEmpty else {
            return nil
        }

        self.set(identity: identity)

        UserDefaults.standard.set(nil, forKey: IdentityDefaults.IdentityKey)

        return identity
    }

    public func reset() {
        self.defaults.set(nil, forKey: IdentityDefaults.IdentityKey)
    }
}
