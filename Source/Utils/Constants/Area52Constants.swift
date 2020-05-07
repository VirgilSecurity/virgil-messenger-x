//
//  Area52Constants.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 5/7/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

extension Constants {
    static let KeychainGroup: String = "com.virgil.Area52Messenger"
    static let appGroup: String = "group.virgil.area52messenger"

    // FIXME: Use env variable
    static let launchScreenName: String = "Area52Start"
}

extension URLConstants {
    static let ejabberdHost: String = "xmpp.area52.virgil.net"

    static let serviceBaseURL: String = "https://messenger.area52.virgil.net"
}
