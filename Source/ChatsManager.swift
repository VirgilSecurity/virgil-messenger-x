//
//  ChatManager.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/26/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import Foundation
import VirgilE3Kit

public enum ChatsManager {
    public static func startDrSession(with identity: String,
                                      startProgressBar: @escaping (() -> Void),
                                      completion: @escaping (Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let identity = identity.lowercased()

                guard identity != Virgil.ethree.identity else {
                    throw UserFriendlyError.createSelfChatForbidded
                }

                guard !Storage.shared.existsSingleChannel(with: identity) else {
                    throw UserFriendlyError.doubleChannelForbidded
                }

                startProgressBar()

                let card = try Virgil.ethree.findUser(with: identity).startSync().get()
                
                _ = try Virgil.ethree.createRatchetChannel(with: card).startSync().get()

                try Storage.shared.createSingleChannel(initiator: Virgil.ethree.identity, card: card)

                completion(nil)
            }
            catch FindUsersError.cardWasNotFound {
                completion(UserFriendlyError.userNotFound)
            }
            catch {
                completion(error)
            }
        }
    }
}
