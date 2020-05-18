//
//  PushRegistryDelegate.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/22/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import PushKit

class PushRegistryDelegate: NSObject, PKPushRegistryDelegate {

    enum Error: LocalizedError {
        case parsingFailed
    }

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

        guard type == .voIP else {
            Log.debug("Received non VoIP push notification.")
            return
        }

        do {
            guard
                let caller = payload.dictionaryPayload["from"] as? String,
                let body = payload.dictionaryPayload["body"] as? String
            else {
                throw Error.parsingFailed
            }

            try UserAuthorizer().signIn()

            let encryptedMessage = try EncryptedMessage.import(body)

            let callOffer = try MessageProcessor.process(call: encryptedMessage, from: caller)

            CallManager.shared.startIncomingCall(from: callOffer, pushKitCompletion: completion)
        }
        catch {
            Log.error(error, message: "Incoming call processing failed")

            CallManager.shared.startDummyIncomingCall(pushKitCompletion: completion)
        }
    }
}
