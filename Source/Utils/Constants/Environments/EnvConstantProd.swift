//
//  EnvConstants.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/30/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

extension Constants {
    static let envPrefix: EnvPrefix = .prod
}

extension URLConstants {

    // From RFC 8445:
    // ... the agent uses STUN or TURN to obtain additional candidates.
    // These come in two flavors: translated addresses on the public side of
    // a NAT (server-reflexive candidates) and addresses on TURN servers
    // (relayed candidates).  When TURN servers are utilized, both types of
    // candidates are obtained from the TURN server.
    static let ejabberdTurnServers: [String] = ["turn:turn1.virgilsecurity.com",
                                                "turn:turn2.virgilsecurity.com"]
}
