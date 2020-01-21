//
//  UserFriendlyError.swift
//  Morse
//
//  Created by Yevhen Pyvovarov on 3/25/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import Foundation

enum UserFriendlyError: String, Error {
    case noUserOnDevice = "User not found on this device"
    case usernameAlreadyUsed = "Username is already in use"
    case createSelfChatForbidded = "You need to communicate with other people :)"
    case doubleChannelForbidded = "You already have this channel"
    case userNotFound = "User not found"
    case noConnection = "Please check your network connection"
    case unknownError = "Something went wrong"
    case playingError = "Playing error"
    case memberAlreadyExists = "This user is already a member of channel"
    case connectionIssue = "Connection failed"

    init(from error: Error) {
        self = error as? UserFriendlyError ?? .unknownError
    }
}
