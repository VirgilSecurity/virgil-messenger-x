//
//  PushRegistryDelegate.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/22/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import PushKit

class PushRegistryDelegate: NSObject, PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else {
            return
        }

        let deviceToken = pushCredentials.token

        Log.debug("Received device voip token: \(deviceToken.hexEncodedString())")

        if Ejabberd.shared.state == .connected {
            Ejabberd.shared.registerForNotifications(voipDeviceToken: deviceToken)
        }

        Ejabberd.updatedVoipPushToken = deviceToken
    }

    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType,
                      completion: @escaping () -> Void) {

        defer {
            completion()
        }

        guard type == .voIP else {
            Log.debug("Received non VoIP push notification.")
            return
        }

        // FIXME: Minimize payload
        guard
            let aps = payload.dictionaryPayload["aps"] as? NSDictionary,
            let alert = aps["alert"] as? NSDictionary,
            let caller = alert["title"] as? String,
            let body = alert["body"] as? String
        else {
            Log.error(NSError(), message: "Failed to parse VoIP push message.")
            return
        }

        // FIXME: Replace with appropriate call that awakes ejabberd connection
        Ejabberd.shared.startInitializing(identity: Virgil.ethree.identity)

        do {
            let encryptedMessage = try EncryptedMessage.import(body)

            try MessageProcessor.process(call: encryptedMessage, from: caller)
        }
        catch {
            Log.error(error, message: "Incomming call processing failed")
        }
    }
}
