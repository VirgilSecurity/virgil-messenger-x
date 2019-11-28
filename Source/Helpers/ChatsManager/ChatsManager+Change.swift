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
                // Make changeMembersMessage
                let text = "added \(newMembers.joined(separator: ", "))"
                let message = try CoreData.shared.createChangeMembersMessage(text, isIncoming: false)

                // Send Service Message to group chat
                try dataSource.addChangeMembers(message: message)

                // Invite members to Twilio Channel
                try Twilio.shared.add(members: newMembers).startSync().get()

                let newUsers = try Virgil.ethree.findUsers(with: newMembers).startSync().get()

                let group = try dataSource.channel.getGroup()
                try group.add(participants: newUsers).startSync().get()

                // Adding cards to Core Data
                let participants = try Virgil.ethree.findUsers(with: Array(group.participants)).startSync().get()
                let cards = Array(participants.values)
                try CoreData.shared.updateCards(with: cards, for: dataSource.channel)

                completion((), nil)
            } catch {
                completion(nil, error)
            }
        }
    }

//    internal static func removeMember(_ remove: String, dataSource: DataSource) -> CallbackOperation<Void> {
//        return CallbackOperation { _, completion in
//            do {
//                let currentMembers = dataSource.channel.cards.map { $0.identity }
//                let members = currentMembers.filter { $0 != remove}
//
//                // Generating ticket
//                let ticket = try Virgil.shared.createChangeMemebersTicket(in: dataSource.channel)
//
//                // Create Single Service Message with ticket and send it
//                let serviceMessage = try ServiceMessage(message: ticket,
//                                                        members: members + [Twilio.shared.identity],
//                                                        add: [],
//                                                        remove: [remove])
//
//                try MessageSender.sendServiceMessage(to: members + [remove], ticket: serviceMessage).startSync().get()
//
//                // Send Service Message to Group chat
//                try dataSource.addChangeMembers(serviceMessage)
//
//                // Remove guy from Twilio channel (attributes for now)
//                try Twilio.shared.remove(member: remove).startSync().get()
//
//                let removeCards = try Virgil.shared.getCards(of: [remove])
//
//                // Use ticket on session
//                try Virgil.shared.updateParticipants(ticket: ticket, channel: dataSource.channel, remove: removeCards)
//
//                // Remove cards from Core Data
//                try CoreData.shared.remove(removeCards, from: dataSource.channel)
//
//                // Delete Single Service Message from Core Data
//                try CoreData.shared.delete(serviceMessage)
//
//                completion((), nil)
//            } catch {
//                completion(nil, error)
//            }
//        }
//    }
}
