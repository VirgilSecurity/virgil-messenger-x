//
//  SecureChat.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/29/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import Foundation
import VirgilSDKRatchet

extension SecureChat {
    @objc public func existingGroupSession(sessionId: Data) -> SecureGroupSession? {
        let identifier = sessionId.hexEncodedString()
        if let session = self.groupSessionStorage.retrieveSession(identifier: identifier) {
            Log.debug("Found existing group session with identifier: \(sessionId)")

            return session
        }
        else {
            Log.debug("Existing session with identifier: \(sessionId) was not found")

            return nil
        }
    }
}

