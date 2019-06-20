//
//  ChatsManager+ChangeMembers.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 5/31/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK

extension ChatsManager {
    internal static func addMembers(_ cards: [Card], dataSource: DataSource) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let newCards = dataSource.channel.cards + cards

                // Generating ticket
                let ticket = try Virgil.shared.createChangeMemebersTicket(in: dataSource.channel)

                // Create Single Service Message with ticket and send it
                let user = try Virgil.shared.localKeyManager.retrieveUserData()

                let serviceMessage = try ServiceMessage(identifier: UUID().uuidString,
                                                        message: ticket,
                                                        type: .changeMembers,
                                                        members: newCards + [user.card],
                                                        add: cards,
                                                        remove: [])

                try MessageSender.sendServiceMessage(to: newCards, ticket: serviceMessage).startSync().getResult()

                // Send Service Message to group chat
                try dataSource.addChangeMembers(serviceMessage)

                // Invite members to Twilio Channel
                let identities = cards.map { $0.identity }
                try Twilio.shared.add(members: identities).startSync().getResult()

                // Use ticket on session
                try Virgil.shared.updateParticipants(ticket: ticket, channel: dataSource.channel, addCards: cards)

                // Adding cards to Core Data
                try CoreData.shared.add(cards, to: dataSource.channel)

                // Delete Single Service Message from Core Data
                try CoreData.shared.delete(serviceMessage)

                completion((), nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    internal static func removeMember(_ card: Card, dataSource: DataSource) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let newCards = dataSource.channel.cards.filter { $0.identity != card.identity }

                // Generating ticket
                let ticket = try Virgil.shared.createChangeMemebersTicket(in: dataSource.channel)

                // Create Single Service Message with ticket and send it
                let user = try Virgil.shared.localKeyManager.retrieveUserData()

                let serviceMessage = try ServiceMessage(identifier: UUID().uuidString,
                                                        message: ticket,
                                                        type: .changeMembers,
                                                        members: newCards + [user.card],
                                                        add: [],
                                                        remove: [card])

                try MessageSender.sendServiceMessage(to: newCards + [card], ticket: serviceMessage).startSync().getResult()

                // Send Service Message to Group chat
                try dataSource.addChangeMembers(serviceMessage)

                // Remove guy from Twilio channel (attributes for now)
                try Twilio.shared.remove(member: card.identity).startSync().getResult()

                // Use ticket on session
                try Virgil.shared.updateParticipants(ticket: ticket, channel: dataSource.channel, removeCards: [card])

                // Remove cards from Core Data
                try CoreData.shared.remove([card], from: dataSource.channel)

                // Delete Single Service Message from Core Data
                try CoreData.shared.delete(serviceMessage)

                completion((), nil)
            } catch {
                completion(nil, error)
            }
        }
    }
}
