//
//  ChatManager.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/26/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import VirgilE3Kit

public enum ChatsManager {
    public static func startSingle(with identity: String,
                                   startProgressBar: @escaping (() -> Void),
                                   completion: @escaping (Error?) -> Void) {
        DispatchQueue(label: "ChatsManager").async {
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

                _ = try Storage.shared.createSingleChannel(initiator: Virgil.ethree.identity, card: card)

                completion(nil)
            } catch FindUsersError.cardWasNotFound {
                completion(UserFriendlyError.userNotFound)
            } catch {
                completion(error)
            }
        }
    }

    public static func startSingleRatchet(with identity: String,
                                   startProgressBar: @escaping (() -> Void),
                                   completion: @escaping (Error?) -> Void) {
        DispatchQueue(label: "ChatsManager").async {
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

                // FIXME: Catch related errors
                let ratchetChannel = try Virgil.ethree.getRatchetChannel(with: card)
                if ratchetChannel == nil {
                    _ = try Virgil.ethree.createRatchetChannel(with: card).startSync().get()
                }

                let channel = try Storage.shared.createSingleRatchetChannel(initiator: Virgil.ethree.identity, card: card)

                let sender = MessageSender()
                let ratchetChannelMessage = Message.NewChannel(type: .singleRatchet, initiator: Virgil.ethree.identity)
                sender.send(newChannel: ratchetChannelMessage, date: Date(), channel: channel, completion: completion)
            } catch FindUsersError.cardWasNotFound {
                completion(UserFriendlyError.userNotFound)
            } catch {
                completion(error)
            }
        }
    }
}
