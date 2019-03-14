//
//  VirgilHelper+Authentication.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/19/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation
import VirgilSDK
import VirgilCrypto

extension VirgilHelper {
    func makeInitTwilioOperation(cardId: String, identity: String) -> GenericOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                guard let cardId = self.selfCard?.identifier, let privateKey = self.privateKey else {
                    throw NSError()
                }

                let token = try self.client.getTwilioToken(identity: identity,
                                                           cardId: cardId,
                                                           crypto: self.crypto,
                                                           privateKey: privateKey)

                TwilioHelper.authorize(username: identity, device: "iPhone")
                TwilioHelper.sharedInstance.initialize(token: token) { error in
                    if let error = error {
                        completion(nil, error)
                    } else {
                        completion((), error)
                    }
                }
            } catch {
                Log.error("Error while init twilio: \(error.localizedDescription)")
                completion(nil, VirgilHelperError.gettingTwilioTokenFailed)
            }
        }
    }

    func getTwilioToken(identity: String) throws -> String {
        guard let cardId = self.selfCard?.identifier, let privateKey = self.privateKey else {
            throw NSError()
        }

        return try self.client.getTwilioToken(identity: identity,
                                              cardId: cardId,
                                              crypto: self.crypto,
                                              privateKey: privateKey)
    }
}
