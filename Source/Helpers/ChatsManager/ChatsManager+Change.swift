//
//  ChatsManager+ChangeMembers.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 5/31/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK

extension ChatsManager {
    internal static func addMembers(_ newMembers: [String], dataSource: DataSource) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let currentMembers  = dataSource.channel.cards.map { $0.identity }
                let members = currentMembers + newMembers

                // Generating ticket
                let ticket = try Virgil.shared.createChangeMemebersTicket(in: dataSource.channel)

                // Create Single Service Message with ticket and send it
                let serviceMessage = try ServiceMessage(identifier: UUID().uuidString,
                                                        message: ticket,
                                                        members: members + [Twilio.shared.identity],
                                                        add: newMembers,
                                                        remove: [])

                try MessageSender.sendServiceMessage(to: members, ticket: serviceMessage).startSync().getResult()

                // Send Service Message to group chat
                try dataSource.addChangeMembers(serviceMessage)

                // Invite members to Twilio Channel
                try Twilio.shared.add(members: newMembers).startSync().getResult()

                let newCards = try Virgil.shared.getCards(of: newMembers)

                // Use ticket on session
                try Virgil.shared.updateParticipants(ticket: ticket, channel: dataSource.channel, add: newCards)

                // Adding cards to Core Data
                try CoreData.shared.add(newCards, to: dataSource.channel)

                // Delete Single Service Message from Core Data
                try CoreData.shared.delete(serviceMessage)

                completion((), nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    internal static func removeMember(_ remove: String, dataSource: DataSource) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let currentMembers = dataSource.channel.cards.map { $0.identity }
                let members = currentMembers.filter { $0 != remove}

                // Generating ticket
                let ticket = try Virgil.shared.createChangeMemebersTicket(in: dataSource.channel)

                // Create Single Service Message with ticket and send it
                let serviceMessage = try ServiceMessage(identifier: UUID().uuidString,
                                                        message: ticket,
                                                        members: members + [Twilio.shared.identity],
                                                        add: [],
                                                        remove: [remove])

                try MessageSender.sendServiceMessage(to: members + [remove], ticket: serviceMessage).startSync().getResult()

                // Send Service Message to Group chat
                try dataSource.addChangeMembers(serviceMessage)

                // Remove guy from Twilio channel (attributes for now)
                try Twilio.shared.remove(member: remove).startSync().getResult()

                let removeCards = try Virgil.shared.getCards(of: [remove])

                // Use ticket on session
                try Virgil.shared.updateParticipants(ticket: ticket, channel: dataSource.channel, remove: removeCards)

                // Remove cards from Core Data
                try CoreData.shared.remove(removeCards, from: dataSource.channel)

                // Delete Single Service Message from Core Data
                try CoreData.shared.delete(serviceMessage)

                completion((), nil)
            } catch {
                completion(nil, error)
            }
        }
    }
}
