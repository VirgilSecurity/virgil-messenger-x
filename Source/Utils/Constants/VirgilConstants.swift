//
//  VirgilConstants.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 5/18/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

extension Constants {
    static let KeychainGroup: String = "com.virgil.VirgilMessenger\(Constants.envPrefix.rawValue.replacingOccurrences(of: "-", with: "."))"
    static let appGroup: String = "group.virgil.notification\(Constants.envPrefix.rawValue)"

    // FIXME: Use env variable
    static let launchScreenName: String = "VirgilStart"
}

extension URLConstants {
    static let ejabberdHost: String = "xmpp\(Constants.envPrefix.rawValue).virgilsecurity.com"

    static let serviceBaseURL: String = "https://messenger\(Constants.envPrefix.rawValue).virgilsecurity.com"
}
