//
//  Ejabberd+Pushes.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/9/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import XMPPFrameworkSwift

extension Ejabberd {
    func registerForNotifications(deviceToken: Data? = nil) throws {
        guard let deviceToken = deviceToken ?? Ejabberd.updatedPushToken else {
            return
        }

        guard let pushServerJID = XMPPJID(string: URLConstants.ejabberdPushHost) else {
            throw EjabberdError.jidFormingFailed
        }

        let deviceId = deviceToken.hexEncodedString()

        let options = ["device_id": deviceId,
                       "service": "apns",
                       "mutable_content": "true",
                       "sound": "default",
                       "topic": Constants.KeychainGroup]

        let element = XMPPIQ.enableNotificationsElement(with: pushServerJID,
                                                        node: Constants.pushesNode,
                                                        options: options)

        self.stream.send(element)
    }

    func deregisterFromNotifications() throws {
        guard let pushServerJID = XMPPJID(string: URLConstants.ejabberdPushHost) else {
            throw EjabberdError.jidFormingFailed
        }

        let element = XMPPIQ.disableNotificationsElement(with: pushServerJID, node: Constants.pushesNode)

        self.stream.send(element)
    }
}
