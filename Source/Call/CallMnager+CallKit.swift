//
//  CallMnager+CallKit.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 06.04.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import CallKit

// MARK: - Configuration
extension CallManager {
    static func createCallKitProvider() -> CXProvider {
        let config = CXProviderConfiguration(localizedName: "Virgil Call")
        config.supportsVideo = false
        config.supportedHandleTypes = [.generic]
        config.maximumCallsPerCallGroup = 1
        config.maximumCallGroups = 1
        config.includesCallsInRecents = false

        let provider = CXProvider(configuration: config)

        return provider
    }
}

// MARK: - Delegates
extension CallManager: CXProviderDelegate {
    public func providerDidReset(_ provider: CXProvider) {
        self.endCall()
    }

    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
            action.fulfill()
    }
}
