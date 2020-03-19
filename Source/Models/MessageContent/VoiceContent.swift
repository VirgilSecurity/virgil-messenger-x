//
//  VoiceContent.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/16/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

struct VoiceContent: Codable {
    let identifier: String
    let duration: TimeInterval
    let url: URL
}
