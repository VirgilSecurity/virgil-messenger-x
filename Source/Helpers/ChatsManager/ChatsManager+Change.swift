//
//  ChatsManager+ChangeMembers.swift
//  Morse
//
//  Created by Yevhen Pyvovarov on 5/31/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK

extension ChatsManager {
    internal static func addMembers(_ newMembers: [String], dataSource: DataSource) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                // Add members to virgil group
                let group = try dataSource.channel.getGroup()
                try group.add(participants: newMembers).startSync().get()

                // Send Service Message to group chat
                let text = "added \(newMembers.joined(separator: ", "))"
                try dataSource.addChangeMembers(message: text)

                // Invite members to Twilio Channel
                try Twilio.shared.add(members: newMembers).startSync().get()

                // Adding cards to Core Data
                let participants = try Virgil.ethree.findUsers(with: Array(group.participants)).startSync().get()
                let cards = Array(participants.values)
                try CoreData.shared.updateCards(with: cards, for: dataSource.channel)

                completion((), nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }

    internal static func removeMember(_ member: String, dataSource: DataSource) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let group = try dataSource.channel.getGroup()
                try group.remove(participant: member).startSync().get()

                // Send Service Message to group chat
                let text = "removed \(member)"
                try dataSource.addChangeMembers(message: text)

                // Remove guy from Twilio channel
                try Twilio.shared.remove(member: member).startSync().get()

                // Adding cards to Core Data
                let participants = try Virgil.ethree.findUsers(with: Array(group.participants)).startSync().get()
                let cards = Array(participants.values)
                try CoreData.shared.updateCards(with: cards, for: dataSource.channel)

                completion((), nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }
}
