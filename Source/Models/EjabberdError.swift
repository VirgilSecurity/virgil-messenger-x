//
//  EjabberdError.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/9/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

public enum EjabberdError: Int, Error {
    case connectionTimeout = 1
    case missingBody = 2
    case missingAuthor = 3
    case jidFormingFailed = 4
    case missingStreamJID = 5
    case missingElementId = 6
    case generatingReadResponseFailed = 7
    case generatingDeliveryResponseFailed = 8
}
