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

//    public static func startGroup(with channels: [Storage.Channel],
//                                  name: String,
//                                  startProgressBar: @escaping () -> Void,
//                                  completion: @escaping (Error?) -> Void) {
//        DispatchQueue(label: "ChatsManager").async {
//            do {
//                let name = name.lowercased()
//
//                guard !channels.isEmpty else {
//                    throw UserFriendlyError.unknownError
//                }
//
//                startProgressBar()
//
//                let members = channels.map { $0.name }
//
//                let findUsersResult = try Virgil.ethree.findUsers(with: members).startSync().get()
//
//                let channel = try Twilio.shared.createGroupChannel(with: members, name: name)
//                    .startSync()
//                    .get()
//
//                let sid = try channel.getSid()
//
//                // FIXME: add already exists handler
//                let group = try Virgil.ethree.createGroup(id: sid, with: findUsersResult).startSync().get()
//
//                let cards = Array(findUsersResult.values)
//                let coreChannel = try Storage.shared.createGroupChannel(name: name,
//                                                                         sid: sid,
//                                                                         initiator: group.initiator,
//                                                                         cards: cards)
//                coreChannel.set(group: group)
//
//                completion(nil)
//            }
//            catch {
//                completion(error)
//            }
//        }
//    }
}
