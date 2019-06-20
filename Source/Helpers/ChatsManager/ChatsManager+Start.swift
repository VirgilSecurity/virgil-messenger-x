//
//  ChatManager.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/26/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import TwilioChatClient

public enum ChatsManager {
    public static func startSingle(with identity: String,
                                   startProgressBar: @escaping (() -> Void),
                                   completion: @escaping (Error?) -> Void) {
        DispatchQueue(label: "ChatsManager").async {
            do {
                let identity = identity.lowercased()

                guard identity != Twilio.shared.identity else {
                    throw UserFriendlyError.createSelfChatForbidded
                }

                guard !CoreData.shared.existsSingleChannel(with: identity) else {
                    throw UserFriendlyError.doubleChannelForbidded
                }

                startProgressBar()

                try ChatsManager.startSingle(with: [identity])

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    public static func startSingle(with identities: [String], cards: [Card]? = nil) throws {
        guard !identities.isEmpty else {
            return
        }

        let cards = try cards ?? Virgil.shared.makeGetCardsOperation(identities: identities).startSync().getResult()

        try Twilio.shared.createSingleChannel(with: cards).startSync().getResult()
    }
    
    public static func startGroup(with channels: [Channel],
                                  name: String,
                                  startProgressBar: @escaping () -> Void,
                                  completion: @escaping (Error?) -> Void) {
        DispatchQueue(label: "ChatsManager").async {
            do {
                let name = name.lowercased()

                guard !channels.isEmpty else {
                    throw UserFriendlyError.unknownError
                }

                startProgressBar()

                let members = channels.map { $0.name }

                let user = try Virgil.shared.localKeyManager.retrieveUserData()

                let cards = channels.map { $0.cards.first! } + [user.card]

                let session = try Virgil.shared.startNewGroupSession(with: cards)

                try Twilio.shared.createGroupChannel(with: members,
                                                           name: name,
                                                           sessionId: session.identifier).startSync().getResult()

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
}
