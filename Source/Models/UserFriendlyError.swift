//
//  UserFriendlyError.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/25/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import Foundation

enum UserFriendlyError: String, Error {
    case noUserOnDevice = "User not found on this device"
    case usernameAlreadyUsed = "Username is already in use"
    case createSelfChatForbidded = "You need to communicate with other people :)"
    case douleChannelForbidded = "You already have this channel"
    case userNotFound = "User not found"
}
