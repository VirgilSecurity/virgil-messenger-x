//
//  Ejabberd+Pushes.swift
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

    func registerForNotifications(deviceToken: Data? = nil, voipDeviceToken: Data? = nil) {
        do {
            var options: [String: String] = [:]

            if let deviceToken = deviceToken ?? Ejabberd.updatedPushToken {
                let deviceId = deviceToken.hexEncodedString()

                options["device_id"] = deviceId
            }

            if let voipDeviceToken = voipDeviceToken ?? Ejabberd.updatedVoipPushToken {
                let voipDeviceId = voipDeviceToken.hexEncodedString()

                options["voip_device_id"] = voipDeviceId
            }

            if options.isEmpty {
                return
            }

            options["service"] = "apns"
            options["mutable_content"] = "true"
            options["sound"] = "default"
            options["topic"] = Constants.alertTopic
            options["push_mode"] = Constants.pushMode
            options["body_type"] = Constants.pushBodyType.rawValue

            guard let pushServerJID = XMPPJID(string: URLConstants.ejabberdPushHost) else {
                throw EjabberdError.jidFormingFailed
            }

            let element = XMPPIQ.enableNotificationsElement(with: pushServerJID,
                                                            node: Constants.pushesNode,
                                                            options: options)

            self.stream.send(element)
        }
        catch {
            Log.error(error, message: "Registering for notifications failed")
        }
    }

    func deregisterFromNotifications() throws {
        guard let pushServerJID = XMPPJID(string: URLConstants.ejabberdPushHost) else {
            throw EjabberdError.jidFormingFailed
        }

        let element = XMPPIQ.disableNotificationsElement(with: pushServerJID, node: Constants.pushesNode)

        self.stream.send(element)
    }
}
