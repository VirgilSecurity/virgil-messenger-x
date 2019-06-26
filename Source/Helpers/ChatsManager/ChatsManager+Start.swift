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

    public static func startSingle(with identities: [String]) throws {
        guard !identities.isEmpty else {
            return
        }

        let cards = try Virgil.shared.makeGetCardsOperation(identities: identities).startSync().getResult()

        try self.startSingle(cards: cards)
    }

    public static func startSingle(cards: [Card]) throws {
        guard !cards.isEmpty else {
            return
        }

        try Twilio.shared.createSingleChannel(with: cards)
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

                let cards = try channels.map { try $0.getCard() }

                let id = try Virgil.shared.crypto.generateRandomData(ofSize: 32)

                try Virgil.shared.startNewGroupSession(with: cards, sessionId: id)

                try Twilio.shared.createGroupChannel(with: cards, name: name, id: id).startSync().getResult()

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
}
