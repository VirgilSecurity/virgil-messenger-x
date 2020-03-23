//
//  CallStrings.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 23.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

struct CallStatusString {
    static let startCalling = "Calling"
    static let waitingForAnswer = "Waiting for answer"
    static let negotiateConnection = "Negotiate connection"
    static let connected = "Connected"
    static let rejected = "Rejected"
    static let finished = "Finished"
    static let cannotConnect = "Cannot connect"
}

struct ConnectionStatusString {
    static let undefined = "..."
    static let connecting = "Connecting"
    static let connected = "Connected"
    static let disconnected = "Disconnected"
    static let loseConnection = "Lose connection"
    static let reconnecting = "Reconnecting"
    static let failed = "Failed"
}
