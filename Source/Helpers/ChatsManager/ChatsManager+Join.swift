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
        let attributes = try TwilioHelper.shared.getAttributes(of: channel)

        switch attributes.type {
        case .single:
            let name = TwilioHelper.shared.getCompanion(from: attributes)

            let cards = try VirgilHelper.shared.makeGetCardsOperation(identities: [name]).startSync().getResult()

            try CoreDataHelper.shared.createSingleChannel(sid: channel.sid!, card: cards.first!)

        case .group:
            let members = attributes.members.filter { !CoreDataHelper.shared.existsSingleChannel(with: $0) && $0 != TwilioHelper.shared.username }

            try ChatsManager.makeStartSingleOperation(with: members)

            try CoreDataHelper.shared.createGroupChannel(name: attributes.friendlyName!, members: attributes.members, sid: channel.sid!)
        }
    }
}
