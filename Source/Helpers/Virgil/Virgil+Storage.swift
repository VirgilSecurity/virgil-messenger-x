//
//  Virgil+Storage.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 31.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

extension Virgil {
    public static func resolveChannel(_ channel: Storage.Channel, with newChannel: NetworkMessage.NewChannel) throws {
        // single -> singleRatchet
        if channel.type == .single && newChannel.type == .singleRatchet {
            _ = try Virgil.ethree.joinRatchetChannel(with: channel.getCard()).startSync().get()

            try Storage.shared.changeChannel(channel, type: .singleRatchet)
        }
        // singleRatchet -> singleRatchet
        else if channel.type == .singleRatchet && newChannel.type == .singleRatchet {
            // Resolve which ratchet channel will stay: theirs or ours?
            let weLoose =  Virgil.ethree.identity.lowercased().compare(newChannel.initiator.lowercased()) == .orderedAscending

            if weLoose {
                try Virgil.ethree.deleteRatchetChannel(with: channel.getCard()).startSync().get()
                _ = try Virgil.ethree.joinRatchetChannel(with: channel.getCard()).startSync().get()
            }
        }
        else {
            // TODO: Change to appropriate error, i.e. Not Supported Operation
            throw UserFriendlyError.unknownError
        }
    }
}
