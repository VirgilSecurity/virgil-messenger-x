//
//  Ejabberd+State.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/9/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

extension Ejabberd {
    internal enum State {
        case connected
        case connecting
        case disconnected
    }
}
