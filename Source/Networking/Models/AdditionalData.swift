//
//  AdditionalData.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 29.04.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

public struct AdditionalData: Codable {
    var thumbnail: Data?
    var prekeyMessage: Data?
}
