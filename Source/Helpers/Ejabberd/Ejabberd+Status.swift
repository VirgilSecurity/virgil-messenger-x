//
//  Ejabberd+Status.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/9/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import XMPPFrameworkSwift

extension Ejabberd {
    enum Status {
        case online
        case unavailable
    }

    public func set(status: Status) {
        let presence: XMPPPresence

        switch status {
        case .online:
            presence = XMPPPresence()
        case .unavailable:
            presence = XMPPPresence(type: .unavailable,
                                    show: nil,
                                    status: nil,
                                    idle: nil,
                                    to: nil)
        }

        self.stream.send(presence)
    }
}
