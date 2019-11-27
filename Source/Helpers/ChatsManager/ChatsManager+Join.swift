//
//  ChatsManager+Join.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 5/3/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import TwilioChatClient

extension ChatsManager {
    public static func join(_ channel: TCHChannel) throws {
        let attributes = try channel.getAttributes()

        switch attributes.type {
        case .single:
            let sid = try channel.getSid()

            let name = try Twilio.shared.getCompanion(from: attributes)

            let card = try Virgil.ethree.findUser(with: name).startSync().get()

            try CoreData.shared.createSingleChannel(sid: sid, card: card)

        case .group:
            let result = try Virgil.ethree.findUsers(with: attributes.members).startSync().get()
            let cards = Array(result.values)

            let sessionId = try channel.getSessionId()
            let name = try channel.getFriendlyName()
            let sid = try channel.getSid()

            try CoreData.shared.createGroupChannel(name: name,
                                                   members: attributes.members,
                                                   sid: sid,
                                                   sessionId: sessionId,
                                                   cards: cards)

            let initiatorCard = try Virgil.ethree.findUser(with: attributes.initiator).startSync().get()

            do {
                _ = try Virgil.ethree.loadGroup(id: sessionId, initiator: initiatorCard).startSync().get()
            }
            catch {
                throw error
            }
        }
    }
}
